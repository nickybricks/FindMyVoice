import SwiftUI

struct SettingsView: View {
    @State private var config = AppConfig.default
    @State private var loadError: String?
    @State private var saving = false
    @State private var selectedTab: SettingsTab = .configuration

    // NeMo install state
    @State private var nemoInstalled: Bool?
    @State private var nemoChecking = false
    @State private var nemoInstalling = false
    @State private var nemoInstallStatus = ""
    @State private var nemoInstallError: String?

    var body: some View {
        NavigationSplitView {
            SettingsSidebar(selection: $selectedTab)
        } detail: {
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 720, height: 520)
        .task {
            await loadConfig()
            if config.apiProvider == "nemo" {
                await checkNemoStatus()
            }
        }
        .onChange(of: config) { _, _ in
            // Auto-save on change
            Task { await saveConfig() }
        }
    }

    // MARK: - Detail View Router

    @ViewBuilder
    private var detailView: some View {
        switch selectedTab {
        case .home:
            HomeView()
        case .modes:
            ModesView()
        case .vocabulary:
            VocabularyView()
        case .configuration:
            ConfigurationView(config: $config, onSave: saveConfig)
        case .modelsLibrary:
            ModelsLibraryView(
                config: $config,
                onSave: saveConfig,
                nemoInstalled: $nemoInstalled,
                nemoChecking: $nemoChecking,
                nemoInstalling: $nemoInstalling,
                nemoInstallStatus: $nemoInstallStatus,
                nemoInstallError: $nemoInstallError,
                checkNemoStatus: checkNemoStatus,
                startNemoInstall: startNemoInstall
            )
        case .history:
            HistoryView()
        }
    }

    // MARK: - Helpers

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
            var toSave = config
            if toSave.apiProvider == "nemo" && nemoInstalled != true {
                toSave.apiProvider = "openai"
            }
            try await APIClient.shared.saveConfig(toSave)
            loadError = nil
        } catch {
            loadError = "Failed to save"
        }
    }

    private func checkNemoStatus() async {
        nemoChecking = true
        defer { nemoChecking = false }
        do {
            let status = try await APIClient.shared.fetchNemoStatus()
            nemoInstalled = status.installed
        } catch {
            nemoInstalled = nil
        }
    }

    private func startNemoInstall() async {
        nemoInstalling = true
        nemoInstallError = nil
        nemoInstallStatus = "Starting installation..."

        do {
            let success = try await APIClient.shared.installNemo { line in
                Task { @MainActor in
                    nemoInstallStatus = line
                }
            }
            nemoInstalling = false
            if success {
                nemoInstalled = true
                await saveConfig()
            } else {
                nemoInstallError = "Installation failed. Check logs and try again."
            }
        } catch {
            nemoInstalling = false
            nemoInstallError = "Installation failed: \(error.localizedDescription)"
        }
    }
}
