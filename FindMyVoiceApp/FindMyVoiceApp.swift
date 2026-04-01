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
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    @Published var isRecording = false

    private var currentHotkey: String = "f5"
    private var statusTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        requestAccessibilityIfNeeded()
        startBackend()
        loadHotkeyFromConfig()
        installHotkeyMonitor()
        startStatusPolling()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        statusTimer?.invalidate()
        stopBackend()
    }

    // MARK: - Accessibility

    private func requestAccessibilityIfNeeded() {
        let trusted = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        )
        logger.info("Accessibility trusted: \(trusted)")
        if !trusted {
            logger.warning("Accessibility permission NOT granted — hotkey will not work")
        }
    }

    // MARK: - Global hotkey

    private func loadHotkeyFromConfig() {
        Task {
            if let config = try? await APIClient.shared.fetchConfig() {
                await MainActor.run { self.currentHotkey = config.hotkey }
            }
        }
    }

    private func installHotkeyMonitor() {
        // Use CGEventTap at HID level to intercept F-keys before media key remapping
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        // Store self as unmanaged pointer for the C callback
        let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: { _, _, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon else { return Unmanaged.passRetained(event) }
                let delegate = Unmanaged<AppDelegate>.fromOpaque(refcon).takeUnretainedValue()
                let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
                let targetKeyCode = AppDelegate.keyCodeForHotkey(delegate.currentHotkey)
                logger.debug("Key event received: keyCode=\(keyCode), target=\(targetKeyCode)")
                if keyCode == targetKeyCode {
                    logger.info("Hotkey matched! Toggling recording.")
                    delegate.handleHotkeyPress()
                }
                return Unmanaged.passRetained(event)
            },
            userInfo: refcon
        ) else {
            logger.error("Failed to create event tap — Accessibility permission is required")
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Accessibility Permission Required"
                alert.informativeText = "FindMyVoice needs Accessibility permission for the global hotkey.\n\nGo to System Settings → Privacy & Security → Accessibility and enable FindMyVoice."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Open System Settings")
                alert.addButton(withTitle: "OK")
                if alert.runModal() == .alertFirstButtonReturn {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                }
            }
            return
        }

        self.eventTap = tap
        self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        logger.info("Global hotkey monitor installed (CGEventTap) — listening for \(self.currentHotkey)")
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
                    await MainActor.run { self.currentHotkey = config.hotkey }
                }
            }
        }
    }

    // MARK: - Backend lifecycle

    private func findProjectRoot() -> String? {
        let fm = FileManager.default
        let bundle = Bundle.main

        // 1. Check inside app bundle Resources
        if let resourcePath = bundle.resourcePath {
            let script = "\(resourcePath)/backend/findmyvoice_core.py"
            if fm.fileExists(atPath: script) {
                return resourcePath
            }
        }

        // 2. Walk up from the .app bundle looking for backend/findmyvoice_core.py
        var url = URL(fileURLWithPath: bundle.bundlePath).deletingLastPathComponent()
        for _ in 0..<10 {
            let script = url.appendingPathComponent("backend/findmyvoice_core.py").path
            if fm.fileExists(atPath: script) {
                return url.path
            }
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path { break }
            url = parent
        }

        return nil
    }

    private func startBackend() {
        guard let projectRoot = findProjectRoot() else {
            logger.error("Could not find findmyvoice_core.py")
            return
        }

        let scriptPath = "\(projectRoot)/backend/findmyvoice_core.py"
        let venvPython = "\(projectRoot)/backend/venv/bin/python"
        let pythonPath = FileManager.default.fileExists(atPath: venvPython) ? venvPython : "/usr/bin/python3"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = [scriptPath]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            backendProcess = process
            logger.info("Backend started (pid \(process.processIdentifier))")
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
