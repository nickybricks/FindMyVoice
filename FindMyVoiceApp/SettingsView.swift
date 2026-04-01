import SwiftUI

struct SettingsView: View {
    @State private var config = AppConfig.default
    @State private var loadError: String?
    @State private var saving = false

    private let hotkeys = ["f1","f2","f3","f4","f5","f6","f7","f8","f9","f10","f11","f12"]

    private let openaiModels = [
        "whisper-1",
        "whisper-large-v3",
        "whisper-large-v3-turbo",
    ]

    private let openaiLanguages: [(String, String)] = [
        ("auto", "Auto-detect"),
        ("en", "English"),
        ("fr", "French"),
        ("de", "German"),
        ("es", "Spanish"),
        ("it", "Italian"),
        ("pt", "Portuguese"),
        ("nl", "Dutch"),
        ("pl", "Polish"),
        ("ru", "Russian"),
        ("uk", "Ukrainian"),
        ("cs", "Czech"),
        ("sk", "Slovak"),
        ("ro", "Romanian"),
        ("hu", "Hungarian"),
        ("bg", "Bulgarian"),
        ("hr", "Croatian"),
        ("da", "Danish"),
        ("et", "Estonian"),
        ("fi", "Finnish"),
        ("el", "Greek"),
        ("lv", "Latvian"),
        ("lt", "Lithuanian"),
        ("sl", "Slovenian"),
        ("sv", "Swedish"),
        ("tr", "Turkish"),
        ("ar", "Arabic"),
        ("hi", "Hindi"),
        ("ja", "Japanese"),
        ("ko", "Korean"),
        ("zh", "Chinese"),
    ]

    private let nemoLanguages: [(String, String)] = [
        ("auto", "Auto-detect"),
        ("en", "English"),
        ("bg", "Bulgarian"),
        ("hr", "Croatian"),
        ("cs", "Czech"),
        ("da", "Danish"),
        ("nl", "Dutch"),
        ("et", "Estonian"),
        ("fi", "Finnish"),
        ("fr", "French"),
        ("de", "German"),
        ("el", "Greek"),
        ("hu", "Hungarian"),
        ("it", "Italian"),
        ("lv", "Latvian"),
        ("lt", "Lithuanian"),
        ("mt", "Maltese"),
        ("pl", "Polish"),
        ("pt", "Portuguese"),
        ("ro", "Romanian"),
        ("ru", "Russian"),
        ("sk", "Slovak"),
        ("sl", "Slovenian"),
        ("es", "Spanish"),
        ("sv", "Swedish"),
        ("uk", "Ukrainian"),
    ]

    private let systemSounds: [String] = {
        let soundsDir = "/System/Library/Sounds"
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: soundsDir) else { return [] }
        return files
            .filter { $0.hasSuffix(".aiff") }
            .map { $0.replacingOccurrences(of: ".aiff", with: "") }
            .sorted()
    }()

    var body: some View {
        TabView {
            generalTab.tabItem { Label("General", systemImage: "gearshape") }
            apiTab.tabItem { Label("API", systemImage: "network") }
            soundsTab.tabItem { Label("Sounds", systemImage: "speaker.wave.2") }
            aboutTab.tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 460, height: 380)
        .task { await loadConfig() }
    }

    // MARK: - General

    private var generalTab: some View {
        Form {
            GroupBox("Hotkey") {
                Picker("Trigger key", selection: $config.hotkey) {
                    ForEach(hotkeys, id: \.self) { Text($0.uppercased()).tag($0) }
                }
            }

            GroupBox("Options") {
                Toggle("Auto-paste into active app", isOn: $config.autoPaste)
                Toggle("Auto-capitalize", isOn: $config.autoCapitalize)
                Toggle("Auto-punctuate", isOn: $config.autoPunctuate)
            }

            saveButton
        }
        .padding()
    }

    // MARK: - API

    private var apiTab: some View {
        Form {
            GroupBox("Provider") {
                Picker("Provider", selection: $config.apiProvider) {
                    Text("OpenAI").tag("openai")
                    Text("NeMo (Local)").tag("nemo")
                }
            }

            if config.apiProvider == "openai" {
                GroupBox("Credentials") {
                    SecureField("API Key", text: $config.apiKey)
                        .textFieldStyle(.roundedBorder)
                    Picker("Model", selection: $config.openaiModel) {
                        ForEach(openaiModels, id: \.self) { Text($0).tag($0) }
                    }
                    Picker("Language", selection: $config.openaiLanguage) {
                        ForEach(openaiLanguages, id: \.0) { code, name in
                            Text(name).tag(code)
                        }
                    }
                }
            } else {
                GroupBox("Model") {
                    HStack {
                        Text("parakeet-tdt-0.6b-v3")
                            .font(.body)
                        Spacer()
                    }
                    Text("Runs fully on-device. No API key required. Model downloads automatically on first use (~1.2 GB).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("Language", selection: $config.nemoLanguage) {
                        ForEach(nemoLanguages, id: \.0) { code, name in
                            Text(name).tag(code)
                        }
                    }
                }
            }

            saveButton
        }
        .padding()
    }

    // MARK: - Sounds

    private var soundsTab: some View {
        Form {
            GroupBox("Recording Sounds") {
                Picker("Start sound", selection: $config.soundStart) {
                    ForEach(systemSounds, id: \.self) { Text($0).tag($0) }
                }
                Picker("Stop sound", selection: $config.soundStop) {
                    ForEach(systemSounds, id: \.self) { Text($0).tag($0) }
                }
            }

            saveButton
        }
        .padding()
    }

    // MARK: - About

    private var aboutTab: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "mic.fill")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
            Text("FindMyVoice")
                .font(.title.bold())
            Text("Version 1.0")
                .foregroundStyle(.secondary)
            Text("Lightweight voice-to-text for macOS.\nPress your hotkey to record, release to transcribe and paste.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 300)
            Spacer()
        }
        .padding()
    }

    // MARK: - Helpers

    private var saveButton: some View {
        HStack {
            Spacer()
            if let err = loadError {
                Text(err).foregroundStyle(.red).font(.caption)
            }
            Button(saving ? "Saving…" : "Save") { Task { await saveConfig() } }
                .disabled(saving)
                .buttonStyle(.borderedProminent)
        }
    }

    private func loadConfig() async {
        do {
            config = try await APIClient.shared.fetchConfig()
            loadError = nil
        } catch {
            loadError = "Cannot reach backend"
        }
    }

    private func saveConfig() async {
        saving = true
        defer { saving = false }
        do {
            try await APIClient.shared.saveConfig(config)
            loadError = nil
        } catch {
            loadError = "Failed to save"
        }
    }
}
