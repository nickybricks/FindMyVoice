import SwiftUI
import Carbon.HIToolbox
import AVFoundation
import ApplicationServices
import os.log

private let logger = Logger(subsystem: "com.findmyvoice", category: "hotkey")

@main
struct FindMyVoiceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.openWindow) private var openWindow
    @State private var nemoWarning = false

    var body: some Scene {
        MenuBarExtra {
            VStack(alignment: .leading, spacing: 4) {
                Text(appDelegate.isRecording ? "Recording…" : "Idle")
                    .font(.headline)
                    .padding(.horizontal, 8)
                    .padding(.top, 4)

                if nemoWarning {
                    Divider()
                    Label("NeMo not installed — reinstall via Settings", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(DS.tertiary)
                        .padding(.horizontal, 8)
                }

                Divider()

                Button("Settings…") {
                    openWindow(id: "settings")
                    NSApp.activate(ignoringOtherApps: true)
                }

                Divider()

                Button("Quit FindMyVoice") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q", modifiers: .command)
            }
            .padding(.vertical, 4)
            .task { await checkNemoOnLaunch() }
        } label: {
            Image(systemName: appDelegate.isRecording ? "mic.fill" : "mic")
        }

        Window("FindMyVoice Settings", id: "settings") {
            SettingsView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }

    private func checkNemoOnLaunch() async {
        // Wait briefly for backend to be ready
        try? await Task.sleep(for: .seconds(2))
        do {
            let config = try await APIClient.shared.fetchConfig()
            guard config.apiProvider == "nemo" else { return }
            let status = try await APIClient.shared.fetchNemoStatus()
            await MainActor.run { nemoWarning = !status.installed }
        } catch {
            // Backend not ready yet — ignore
        }
    }
}

// MARK: - AppDelegate (backend lifecycle + global hotkey)

final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    private var backendProcess: Process?
    private var hotkeyRef: EventHotKeyRef?
    @Published var isRecording = false

    private var currentShortcut: HotkeyCombo = .defaultToggleRecording
    private var statusTimer: Timer?
    private var lastHotkeyTime: Date = .distantPast

    /// Shared reference for the Carbon callback (which can't capture self).
    static weak var shared: AppDelegate?

    // Unique hot key ID
    private static let hotkeyID = EventHotKeyID(signature: OSType(0x464D5648), // "FMVH"
                                                  id: 1)

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("applicationDidFinishLaunching — starting setup")
        AppDelegate.shared = self
        requestPermissions()
        startBackend()
        loadHotkeyFromConfig()
        installHotkeyMonitor()
        startStatusPolling()
        logger.info("applicationDidFinishLaunching — setup complete")
    }

    private func requestPermissions() {
        // Microphone — triggers the system dialog on first run
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            logger.info("Microphone permission: \(granted ? "granted" : "denied")")
        }

        // Accessibility — required to paste transcriptions into other apps
        // Passing the prompt option opens System Settings if not yet trusted
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        logger.info("Accessibility trusted: \(trusted)")
    }

    func applicationWillTerminate(_ notification: Notification) {
        unregisterHotkey()
        statusTimer?.invalidate()
        stopBackend()
    }

    // MARK: - Global hotkey (Carbon RegisterEventHotKey)

    private func loadHotkeyFromConfig() {
        logger.info("loadHotkeyFromConfig — current default is '\(self.currentShortcut.key)'")
        Task {
            if let config = try? await APIClient.shared.fetchConfig() {
                let newShortcut = config.toggleRecording
                logger.info("Config loaded — shortcut: '\(newShortcut.key)' modifiers: \(newShortcut.modifiers)")
                await MainActor.run {
                    if self.currentShortcut != newShortcut {
                        self.currentShortcut = newShortcut
                        self.unregisterHotkey()
                        self.registerHotkey()
                    }
                }
            } else {
                logger.warning("Failed to load config — sticking with default '\(self.currentShortcut.key)'")
            }
        }
    }

    private func installHotkeyMonitor() {
        logger.info("installHotkeyMonitor — using Carbon RegisterEventHotKey")

        // Install Carbon event handler for hot key events
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))

        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, _ -> OSStatus in
                var hotkeyID = EventHotKeyID()
                let err = GetEventParameter(event,
                                            EventParamName(kEventParamDirectObject),
                                            EventParamType(typeEventHotKeyID),
                                            nil,
                                            MemoryLayout<EventHotKeyID>.size,
                                            nil,
                                            &hotkeyID)
                guard err == noErr else {
                    logger.error("Failed to get hot key ID from event: \(err)")
                    return err
                }

                if hotkeyID.id == AppDelegate.hotkeyID.id {
                    logger.info("Carbon hotkey fired — toggling recording")
                    DispatchQueue.main.async {
                        guard let delegate = AppDelegate.shared else {
                            logger.error("AppDelegate.shared is nil — cannot handle hotkey")
                            return
                        }
                        // Debounce: ignore key-repeat (must be >0.5s since last press)
                        let now = Date()
                        guard now.timeIntervalSince(delegate.lastHotkeyTime) > 0.5 else {
                            logger.info("Hotkey debounced — ignoring repeat")
                            return
                        }
                        delegate.lastHotkeyTime = now
                        delegate.handleHotkeyPress()
                    }
                    return noErr
                }
                return OSStatus(eventNotHandledErr)
            },
            1,
            &eventType,
            nil,
            nil
        )

        if handlerStatus != noErr {
            logger.error("InstallEventHandler failed: \(handlerStatus)")
            return
        }
        logger.info("Carbon event handler installed")

        registerHotkey()
    }

    private func registerHotkey() {
        guard !currentShortcut.isEmpty else {
            logger.info("No toggle recording shortcut configured — skipping registration")
            return
        }
        // Use stored keyCode directly (layout-independent) with fallback to name mapping
        let keyCode: UInt16 = currentShortcut.keyCode >= 0
            ? UInt16(currentShortcut.keyCode)
            : AppDelegate.keyCodeForKey(currentShortcut.key)
        let modifierMask = AppDelegate.carbonModifiers(from: currentShortcut.modifiers)
        var hotkeyID = AppDelegate.hotkeyID
        var ref: EventHotKeyRef?

        let status = RegisterEventHotKey(UInt32(keyCode),
                                          modifierMask,
                                          hotkeyID,
                                          GetApplicationEventTarget(),
                                          0,
                                          &ref)

        if status == noErr {
            hotkeyRef = ref
            logger.info("Registered hotkey '\(self.currentShortcut.key)' modifiers=\(self.currentShortcut.modifiers) (keyCode=\(keyCode), mask=\(modifierMask))")
        } else {
            logger.error("RegisterEventHotKey failed: \(status)")
        }
    }

    private func unregisterHotkey() {
        if let ref = hotkeyRef {
            UnregisterEventHotKey(ref)
            hotkeyRef = nil
            logger.info("Unregistered previous hotkey")
        }
    }

    private func handleHotkeyPress() {
        Task {
            do {
                if isRecording {
                    logger.info("Stopping recording...")
                    try await APIClient.shared.stopRecording()
                } else {
                    logger.info("Starting recording...")
                    try await APIClient.shared.startRecording()
                }
                let status = try await APIClient.shared.fetchStatus()
                await MainActor.run { self.isRecording = status.recording }
            } catch {
                logger.error("Hotkey action failed: \(error)")
            }
        }
    }

    static func keyCodeForKey(_ name: String) -> UInt16 {
        switch name.lowercased() {
        case "f1":     return UInt16(kVK_F1)
        case "f2":     return UInt16(kVK_F2)
        case "f3":     return UInt16(kVK_F3)
        case "f4":     return UInt16(kVK_F4)
        case "f5":     return UInt16(kVK_F5)
        case "f6":     return UInt16(kVK_F6)
        case "f7":     return UInt16(kVK_F7)
        case "f8":     return UInt16(kVK_F8)
        case "f9":     return UInt16(kVK_F9)
        case "f10":    return UInt16(kVK_F10)
        case "f11":    return UInt16(kVK_F11)
        case "f12":    return UInt16(kVK_F12)
        case "escape": return UInt16(kVK_Escape)
        case "space":  return UInt16(kVK_Space)
        case "tab":    return UInt16(kVK_Tab)
        case "return": return UInt16(kVK_Return)
        case "delete": return UInt16(kVK_Delete)
        case "a": return UInt16(kVK_ANSI_A)
        case "b": return UInt16(kVK_ANSI_B)
        case "c": return UInt16(kVK_ANSI_C)
        case "d": return UInt16(kVK_ANSI_D)
        case "e": return UInt16(kVK_ANSI_E)
        case "f": return UInt16(kVK_ANSI_F)
        case "g": return UInt16(kVK_ANSI_G)
        case "h": return UInt16(kVK_ANSI_H)
        case "i": return UInt16(kVK_ANSI_I)
        case "j": return UInt16(kVK_ANSI_J)
        case "k": return UInt16(kVK_ANSI_K)
        case "l": return UInt16(kVK_ANSI_L)
        case "m": return UInt16(kVK_ANSI_M)
        case "n": return UInt16(kVK_ANSI_N)
        case "o": return UInt16(kVK_ANSI_O)
        case "p": return UInt16(kVK_ANSI_P)
        case "q": return UInt16(kVK_ANSI_Q)
        case "r": return UInt16(kVK_ANSI_R)
        case "s": return UInt16(kVK_ANSI_S)
        case "t": return UInt16(kVK_ANSI_T)
        case "u": return UInt16(kVK_ANSI_U)
        case "v": return UInt16(kVK_ANSI_V)
        case "w": return UInt16(kVK_ANSI_W)
        case "x": return UInt16(kVK_ANSI_X)
        case "y": return UInt16(kVK_ANSI_Y)
        case "z": return UInt16(kVK_ANSI_Z)
        case "0": return UInt16(kVK_ANSI_0)
        case "1": return UInt16(kVK_ANSI_1)
        case "2": return UInt16(kVK_ANSI_2)
        case "3": return UInt16(kVK_ANSI_3)
        case "4": return UInt16(kVK_ANSI_4)
        case "5": return UInt16(kVK_ANSI_5)
        case "6": return UInt16(kVK_ANSI_6)
        case "7": return UInt16(kVK_ANSI_7)
        case "8": return UInt16(kVK_ANSI_8)
        case "9": return UInt16(kVK_ANSI_9)
        default:
            // Try parsing as a raw keyCode number
            if let code = UInt16(name) { return code }
            return UInt16(kVK_F1)
        }
    }

    static func carbonModifiers(from modifiers: [String]) -> UInt32 {
        var mask: UInt32 = 0
        for mod in modifiers {
            switch mod {
            case "command": mask |= UInt32(cmdKey)
            case "shift":   mask |= UInt32(shiftKey)
            case "option":  mask |= UInt32(optionKey)
            case "control": mask |= UInt32(controlKey)
            default: break
            }
        }
        return mask
    }

    // MARK: - Status polling

    private func startStatusPolling() {
        statusTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task {
                guard let self else { return }
                if let status = try? await APIClient.shared.fetchStatus() {
                    await MainActor.run { self.isRecording = status.recording }
                }
                // Also refresh hotkey in case user changed it in settings
                if let config = try? await APIClient.shared.fetchConfig() {
                    await MainActor.run {
                        if self.currentShortcut != config.toggleRecording {
                            self.currentShortcut = config.toggleRecording
                            self.unregisterHotkey()
                            self.registerHotkey()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Backend lifecycle

    /// Returns the directory containing `backend/findmyvoice_core.py`.
    private func findBackendRoot() -> String? {
        let fm = FileManager.default
        let script = "backend/findmyvoice_core.py"

        // 1. Inside app bundle Resources (bundled by make install)
        if let resourcePath = Bundle.main.resourcePath {
            if fm.fileExists(atPath: "\(resourcePath)/\(script)") {
                logger.info("Found backend in app bundle Resources")
                return resourcePath
            }
        }

        // 2. ~/.findmyvoice/backend/ (user-installed)
        let homeBackend = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".findmyvoice").path
        if fm.fileExists(atPath: "\(homeBackend)/\(script)") {
            logger.info("Found backend in ~/.findmyvoice/")
            return homeBackend
        }

        // 3. Walk up from bundle (dev builds run from build dir)
        var url = URL(fileURLWithPath: Bundle.main.bundlePath).deletingLastPathComponent()
        for _ in 0..<10 {
            if fm.fileExists(atPath: url.appendingPathComponent(script).path) {
                logger.info("Found backend walking up from bundle: \(url.path)")
                return url.path
            }
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path { break }
            url = parent
        }

        return nil
    }

    private func findPython(projectRoot: String) -> String {
        let candidates = [
            "\(projectRoot)/backend/venv/bin/python",
            "\(FileManager.default.homeDirectoryForCurrentUser.path)/.findmyvoice/backend/venv/bin/python",
        ]
        for path in candidates {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return "/usr/bin/python3"
    }

    private func startBackend() {
        guard let backendRoot = findBackendRoot() else {
            logger.error("Could not find findmyvoice_core.py — backend will not start")
            return
        }

        let scriptPath = "\(backendRoot)/backend/findmyvoice_core.py"
        let pythonPath = findPython(projectRoot: backendRoot)
        logger.info("Starting backend: \(pythonPath) \(scriptPath)")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = [scriptPath]

        // Log backend output to system log for debugging
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        pipe.fileHandleForReading.readabilityHandler = { handle in
            if let line = String(data: handle.availableData, encoding: .utf8), !line.isEmpty {
                logger.info("backend: \(line)")
            }
        }

        do {
            try process.run()
            backendProcess = process
            logger.info("Backend started (pid \(process.processIdentifier), python=\(pythonPath))")
        } catch {
            logger.error("Failed to start backend: \(error)")
        }
    }

    private func stopBackend() {
        if let process = backendProcess, process.isRunning {
            process.terminate()
            logger.info("Backend stopped")
        }
    }
}
