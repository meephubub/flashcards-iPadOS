import SwiftUI

// MARK: - Design Tokens

enum DS {
    // Typography
    static let fontDisplay = "Canela-Light"          // Elegant editorial serif for month name
    static let fontMono    = "SF Mono"               // Monospaced for day numbers

    // Palette
    static let ink         = Color(hex: "#0D0D0D")
    static let inkFaint    = Color(hex: "#0D0D0D").opacity(0.08)
    static let ghost       = Color(hex: "#F7F6F3")   // Warm off-white background
    static let surface     = Color(hex: "#FFFFFF")
    static let subtext     = Color(hex: "#9A9898")
    static let accent      = Color(hex: "#000000")   // Warm amber — event dot / selection ring
    static let accentSoft  = Color(hex: "#000000").opacity(0.15)

    // Motion
    static let springSnappy    = Animation.spring(response: 0.32, dampingFraction: 0.72)
    static let springGentle    = Animation.spring(response: 0.44, dampingFraction: 0.82)
    static let easeQuick       = Animation.easeOut(duration: 0.18)
}
