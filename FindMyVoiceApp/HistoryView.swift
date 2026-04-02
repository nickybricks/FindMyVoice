import SwiftUI

struct HistoryView: View {
    var body: some View {
        VStack {
            Spacer()
            Image(systemName: "clock")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("History")
                .font(.title2.bold())
                .padding(.top, 8)
            Text("Transcription history coming soon.")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }
}
