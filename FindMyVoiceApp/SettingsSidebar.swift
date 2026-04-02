import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case home = "Home"
    case modes = "Modes"
    case vocabulary = "Vocabulary"
    case configuration = "Configuration"
    case sound = "Sound"
    case modelsLibrary = "Models Library"
    case history = "History"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .modes: return "square.grid.2x2"
        case .vocabulary: return "text.book.closed"
        case .configuration: return "gearshape.fill"
        case .sound: return "speaker.wave.2.fill"
        case .modelsLibrary: return "cpu"
        case .history: return "clock"
        }
    }

    var iconColor: Color {
        switch self {
        case .home: return .orange
        case .modes: return .blue
        case .vocabulary: return .green
        case .configuration: return .gray
        case .sound: return .pink
        case .modelsLibrary: return .purple
        case .history: return .teal
        }
    }
}

struct SettingsSidebar: View {
    @Binding var selection: SettingsTab

    var body: some View {
        VStack(spacing: 0) {
            List(SettingsTab.allCases, selection: $selection) { tab in
                Label {
                    Text(tab.rawValue)
                } icon: {
                    Image(systemName: tab.icon)
                        .symbolRenderingMode(.hierarchical)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(tab.iconColor)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(tab.iconColor.opacity(0.15))
                        )
                        .glassEffect(.regular.tint(tab.iconColor.opacity(0.3)), in: .rect(cornerRadius: 9))
                }
                .tag(tab)
                .padding(.vertical, 2)
            }
            .listStyle(.sidebar)

        }
    }
}
