import SwiftUI

struct SoundSettingsView: View {
    @Binding var config: AppConfig
    var onSave: () async -> Void

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
                Text("Recording Sounds")
                    .font(.headline)

                SettingsCard {
                    VStack(spacing: 0) {
                        HStack {
                            Text("Start sound")
                            Spacer()
                            Picker("", selection: $config.soundStart) {
                                ForEach(systemSounds, id: \.self) { Text($0).tag($0) }
                            }
                            .labelsHidden()
                            .frame(width: 150)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)

                        Divider().padding(.leading, 16)

                        HStack {
                            Text("Stop sound")
                            Spacer()
                            Picker("", selection: $config.soundStop) {
                                ForEach(systemSounds, id: \.self) { Text($0).tag($0) }
                            }
                            .labelsHidden()
                            .frame(width: 150)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                }
            }
            .padding(24)
        }
    }
}
