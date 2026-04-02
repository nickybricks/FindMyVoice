import SwiftUI

struct ModesView: View {
    var body: some View {
        VStack {
            Spacer()
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("Modes")
                .font(.title2.bold())
                .padding(.top, 8)
            Text("Mode profiles coming soon.")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }
}
