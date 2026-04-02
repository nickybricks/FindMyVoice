import SwiftUI

struct HomeView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 40)

                Image(systemName: "mic.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(DS.primary)

                VStack(spacing: 6) {
                    Text("FindMyVoice")
                        .font(.title.bold())
                    Text("Version 1.0")
                        .foregroundStyle(.secondary)
                }

                Text("Lightweight voice-to-text for macOS.\nPress your hotkey to record, release to transcribe and paste.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 300)

                Spacer(minLength: 40)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
        }
    }
}
