import SwiftUI

struct ModelsLibraryView: View {
    @Binding var config: AppConfig
    var onSave: () async -> Void

    // NeMo install state (passed from parent)
    @Binding var nemoInstalled: Bool?
    @Binding var nemoChecking: Bool
    @Binding var nemoInstalling: Bool
    @Binding var nemoInstallStatus: String
    @Binding var nemoInstallError: String?

    var checkNemoStatus: () async -> Void
    var startNemoInstall: () async -> Void

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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                providerSection
                if config.apiProvider == "openai" {
                    openaiSection
                } else {
                    nemoSection
                }
            }
            .padding(24)
        }
    }

    // MARK: - Provider

    private var providerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Provider")
                .font(.headline)

            SettingsCard {
                HStack {
                    Text("API Provider")
                    Spacer()
                    Picker("", selection: $config.apiProvider) {
                        Text("OpenAI").tag("openai")
                        Text("NeMo (Local)").tag("nemo")
                    }
                    .labelsHidden()
                    .frame(width: 160)
                    .onChange(of: config.apiProvider) { _, newValue in
                        if newValue == "nemo" { Task { await checkNemoStatus() } }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
    }

    // MARK: - OpenAI

    private var openaiSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("OpenAI Settings")
                .font(.headline)

            SettingsCard {
                VStack(spacing: 0) {
                    HStack {
                        Text("API Key")
                        Spacer()
                        SecureField("sk-...", text: $config.apiKey)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 220)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    Divider().padding(.leading, 16)

                    HStack {
                        Text("Model")
                        Spacer()
                        Picker("", selection: $config.openaiModel) {
                            ForEach(openaiModels, id: \.self) { Text($0).tag($0) }
                        }
                        .labelsHidden()
                        .frame(width: 220)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    Divider().padding(.leading, 16)

                    HStack {
                        Text("Language")
                        Spacer()
                        Picker("", selection: $config.openaiLanguage) {
                            ForEach(openaiLanguages, id: \.0) { code, name in
                                Text(name).tag(code)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 220)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
            }
        }
    }

    // MARK: - NeMo

    private var nemoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("NeMo Toolkit")
                .font(.headline)

            SettingsCard {
                VStack(alignment: .leading, spacing: 0) {
                    if nemoChecking {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("Checking NeMo status...")
                                .foregroundStyle(.secondary)
                        }
                        .padding(16)
                    } else if nemoInstalled == true {
                        HStack {
                            Text("parakeet-tdt-0.6b-v3")
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)

                        Divider().padding(.leading, 16)

                        Text("Runs fully on-device. No API key required.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)

                        Divider().padding(.leading, 16)

                        HStack {
                            Text("Language")
                            Spacer()
                            Picker("", selection: $config.nemoLanguage) {
                                ForEach(nemoLanguages, id: \.0) { code, name in
                                    Text(name).tag(code)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 160)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    } else if nemoInstalling {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                ProgressView().controlSize(.small)
                                Text("Installing NeMo...")
                                    .font(.headline)
                            }
                            Text(nemoInstallStatus)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .truncationMode(.head)
                        }
                        .padding(16)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("NeMo is not installed.")
                                .font(.headline)
                            Text("To use local AI transcription, the NeMo toolkit needs to be downloaded (~2 GB).")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let error = nemoInstallError {
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                            Button("Install NeMo \u{2014} Free") {
                                Task { await startNemoInstall() }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(16)
                    }
                }
            }
        }
    }
}
