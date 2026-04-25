import SwiftUI

public extension Color {
    // Primary Colors
    static let primaryPurple = Color(hex: "#7C3AED")
    static let primaryIndigo = Color(hex: "#4F46E5")
    
    // Status Colors
    static let successGreen = Color(hex: "#10B981")
    static let errorRed = Color(hex: "#EF4444")
    static let warningYellow = Color(hex: "#F59E0B")
    
    // Channel Colors
    static let webChatBlue = Color(hex: "#3B82F6")
    static let whatsappGreen = Color(hex: "#25D366")
    static let telegramBlue = Color(hex: "#0088CC")
    static let emailGray = Color(hex: "#6B7280")
    
    // Background Colors
    static let backgroundLight = Color(hex: "#F9FAFB")
    static let backgroundDark = Color(hex: "#111827")
    
    /// Initialize Color from hex string
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
