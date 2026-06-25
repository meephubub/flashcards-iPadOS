import SwiftUI

// MARK: - Design Tokens

enum DS {
    // Typography
    static let fontDisplay = "SF Pro Display"       // Modern sans-serif for headings
    static let fontBody    = "SF Pro Text"          // Body text
    static let fontMono    = "SF Mono"               // Monospaced for code/numbers

    // Monochromatic Palette
    static let ink         = Color(hex: "#000000")   // Primary text
    static let inkLight    = Color(hex: "#1A1A1A")   // Secondary text
    static let inkFaint    = Color(hex: "#000000").opacity(0.06)  // Subtle borders
    static let ghost       = Color(hex: "#F5F5F5")   // Light background
    static let surface     = Color(hex: "#FFFFFF")   // White surface
    static let subtext     = Color(hex: "#6B6B6B")   // Tertiary text
    static let accent      = Color(hex: "#000000")   // Primary accent (black)
    static let accentSoft  = Color(hex: "#000000").opacity(0.08)  // Soft accent

    // Motion
    static let springSnappy    = Animation.spring(response: 0.32, dampingFraction: 0.72)
    static let springGentle    = Animation.spring(response: 0.44, dampingFraction: 0.82)
    static let easeQuick       = Animation.easeOut(duration: 0.18)
    static let expand          = Animation.spring(response: 0.5, dampingFraction: 0.75)
}
