import SwiftUI

// Calmer, professional design system for Out Loud
struct AppTheme {
    // Primary color palette - softer, calmer tones
    static let primary = Color(red: 0.4, green: 0.5, blue: 0.9) // Soft blue
    static let secondary = Color(red: 0.3, green: 0.7, blue: 0.6) // Muted teal
    static let accent = Color(red: 0.8, green: 0.5, blue: 0.3) // Warm orange

    // State colors - less intense
    static let recording = Color(red: 0.9, green: 0.3, blue: 0.3) // Softer red
    static let success = Color(red: 0.4, green: 0.7, blue: 0.5) // Gentle green
    static let warning = Color(red: 0.9, green: 0.6, blue: 0.3) // Warm amber

    // Neutrals - calm background tones
    static let surface = Color(.systemBackground)
    static let surfaceSecondary = Color(red: 0.97, green: 0.97, blue: 0.98)
    static let surfaceTertiary = Color(red: 0.95, green: 0.95, blue: 0.96)

    // Text colors
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textTertiary = Color(white: 0.5)

    // Spacing system
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48
    }

    // Corner radius system
    struct Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
    }

    // Shadow system - subtle and calm
    struct Shadow {
        static func light() -> some View {
            Color.black.opacity(0.03)
        }

        static func medium() -> some View {
            Color.black.opacity(0.06)
        }

        static func strong() -> some View {
            Color.black.opacity(0.1)
        }
    }
}

// Custom view modifiers for consistent styling
extension View {
    func cardStyle() -> some View {
        self
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
            .shadow(color: Color.black.opacity(0.02), radius: 2, x: 0, y: 1)
    }

    func sectionCard() -> some View {
        self
            .background(AppTheme.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
    }

    func pillStyle(color: Color = AppTheme.primary) -> some View {
        self
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(color.opacity(0.2), lineWidth: 0.5)
            )
    }
}
