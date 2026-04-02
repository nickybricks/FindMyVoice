import SwiftUI

struct VocabularyView: View {
    var body: some View {
        VStack {
            Spacer()
            Image(systemName: "text.book.closed")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("Vocabulary")
                .font(.title2.bold())
                .padding(.top, 8)
            Text("Custom vocabulary coming soon.")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }
}
