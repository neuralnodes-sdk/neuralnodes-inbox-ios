import Foundation

// Extension to provide channel icon for UI
extension Conversation {
    public var channelIcon: String {
        switch channel {
        case "webchat": return "message.fill"
        case "whatsapp": return "message.badge.filled.fill"
        case "telegram": return "paperplane.fill"
        case "email": return "envelope.fill"
        default: return "message.fill"
        }
    }
    
    public var timeAgo: String {
        // Use lastMessageAt if available, otherwise fall back to updatedAt
        let referenceDate = lastMessageAt ?? updatedAt
        let seconds = Int(Date().timeIntervalSince(referenceDate))
        
        if seconds < 60 {
            return "Just now"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return "\(minutes)m ago"
        } else if seconds < 86400 {
            let hours = seconds / 3600
            return "\(hours)h ago"
        } else {
            let days = seconds / 86400
            return "\(days)d ago"
        }
    }
}
