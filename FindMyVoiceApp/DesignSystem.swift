import SwiftUI

// MARK: - Design System
// Primary: #0088FF  Secondary: #5978aa  Tertiary: #df6402  Neutral: #747780
// Headlines: Manrope  Body/Labels: Inter  (falls back to system fonts if not installed)
// Roundedness: Maximum (pill-shaped corners)

enum DS {

    // MARK: - Brand Colors

    static let primary   = Color(hex: "0088FF")
    static let secondary = Color(hex: "5978AA")
    static let tertiary  = Color(hex: "DF6402")
    static let neutral   = Color(hex: "747780")

    // MARK: - Corner Radii

    /// Large pill radius for badges and small interactive elements
    static let radiusPill: CGFloat = 100
    /// Container cards and panels
    static let radiusCard: CGFloat = 16
    /// Sidebar navigation items
    static let radiusSidebar: CGFloat = 12

    // MARK: - Typography
    // Manrope (headlines) and Inter (body/labels) are loaded if bundled or installed.
    // SwiftUI silently falls back to the system font when a custom font is unavailable.

    static func headline(size: CGFloat = 17, weight: Font.Weight = .semibold) -> Font {
        .custom("Manrope", size: size).weight(weight)
    }

    static func body(size: CGFloat = 14, weight: Font.Weight = .regular) -> Font {
        .custom("Inter", size: size).weight(weight)
    }

    static func label(size: CGFloat = 12, weight: Font.Weight = .medium) -> Font {
        .custom("Inter", size: size).weight(weight)
    }
}

// MARK: - Hex Color Initializer

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double( int        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
