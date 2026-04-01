import SwiftUI
import Carbon.HIToolbox
import os.log

private let logger = Logger(subsystem: "com.findmyvoice", category: "hotkey")

@main
struct FindMyVoiceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra {
            VStack(alignment: .leading, spacing: 4) {
                Text(appDelegate.isRecording ? "Recording…" : "Idle")
                    .font(.headline)
                    .padding(.horizontal, 8)
                    .padding(.top, 4)

                Divider()

                Button("Settings…") { 
                    openWindow(id: "settings")
                    NSApp.activate(ignoringOtherApps: true) // Bring app to foreground when opening setting
                }

                Divider()

                Button("Quit FindMyVoice") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q", modifiers: .command)
            }
            .padding(.vertical, 4)
        } label: {
            Image(systemName: appDelegate.isRecording ? "mic.fill" : "mic")
        }

        Window("FindMyVoice Settings", id: "settings") {
            SettingsView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}

// MARK: - AppDelegate (backend lifecycle + global hotkey)

final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    private var backendProcess: Process?
    private var hotkeyRef: EventHotKeyRef?
    @Published var isRecording = false

    private var currentHotkey: String = "f5"
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
        startBackend()
        loadHotkeyFromConfig()
        installHotkeyMonitor()
        startStatusPolling()
        logger.info("applicationDidFinishLaunching — setup complete")
    }

    func applicationWillTerminate(_ notification: Notification) {
        unregisterHotkey()
        statusTimer?.invalidate()
        stopBackend()
    }

    // MARK: - Global hotkey (Carbon RegisterEventHotKey)

    private func loadHotkeyFromConfig() {
        logger.info("loadHotkeyFromConfig — current default is '\(self.currentHotkey)'")
        Task {
            if let config = try? await APIClient.shared.fetchConfig() {
                let newHotkey = config.hotkey
                logger.info("Config loaded — hotkey: '\(newHotkey)'")
                await MainActor.run {
                    if self.currentHotkey != newHotkey {
                        self.currentHotkey = newHotkey
                        self.unregisterHotkey()
                        self.registerHotkey()
                    }
                }
            } else {
                logger.warning("Failed to load config — sticking with default '\(self.currentHotkey)'")
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
        let keyCode = AppDelegate.keyCodeForHotkey(currentHotkey)
        var hotkeyID = AppDelegate.hotkeyID
        var ref: EventHotKeyRef?

        let status = RegisterEventHotKey(UInt32(keyCode),
                                          0, // no modifiers
                                          hotkeyID,
                                          GetApplicationEventTarget(),
                                          0,
                                          &ref)

        if status == noErr {
            hotkeyRef = ref
            logger.info("Registered hotkey '\(self.currentHotkey)' (keyCode=\(keyCode)) — no modifiers")
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

    private static func keyCodeForHotkey(_ name: String) -> UInt16 {
        switch name.lowercased() {
        case "f1":  return UInt16(kVK_F1)
        case "f2":  return UInt16(kVK_F2)
        case "f3":  return UInt16(kVK_F3)
        case "f4":  return UInt16(kVK_F4)
        case "f5":  return UInt16(kVK_F5)
        case "f6":  return UInt16(kVK_F6)
        case "f7":  return UInt16(kVK_F7)
        case "f8":  return UInt16(kVK_F8)
        case "f9":  return UInt16(kVK_F9)
        case "f10": return UInt16(kVK_F10)
        case "f11": return UInt16(kVK_F11)
        case "f12": return UInt16(kVK_F12)
        default:    return UInt16(kVK_F1)
        }
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
                        if self.currentHotkey != config.hotkey {
                            self.currentHotkey = config.hotkey
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
