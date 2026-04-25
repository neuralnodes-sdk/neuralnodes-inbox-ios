import SwiftUI

/// Communication channel types
public enum Channel: String, CaseIterable, Identifiable {
    case all = "all"
    case whatsapp = "whatsapp"
    case telegram = "telegram"
    case email = "email"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .all: return "All Channels"
        case .whatsapp: return "WhatsApp"
        case .telegram: return "Telegram"
        case .email: return "Email"
        }
    }
    
    public var icon: String {
        switch self {
        case .all: return "tray.2.fill"
        case .whatsapp: return "message.badge.filled.fill"
        case .telegram: return "paperplane.fill"
        case .email: return "envelope.fill"
        }
    }
    
    public var color: Color {
        switch self {
        case .all: return .primary
        case .whatsapp: return .whatsappGreen
        case .telegram: return .telegramBlue
        case .email: return .emailGray
        }
    }
    
    public var emoji: String {
        switch self {
        case .all: return "📱"
        case .whatsapp: return "💬"
        case .telegram: return "✈️"
        case .email: return "📧"
        }
    }
}
