import SwiftUI

public struct ConversationRow: View {
    let conversation: Conversation
    @Environment(\.colorScheme) var colorScheme
    
    public init(conversation: Conversation) {
        self.conversation = conversation
    }
    
    public var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Premium Channel Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                channelColor.opacity(0.15),
                                channelColor.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)
                
                Image(systemName: conversation.channelIcon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(channelColor)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                // Name and Time
                HStack(alignment: .top) {
                    Text(conversation.displayName)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer(minLength: 8)
                    
                    Text(conversation.timeAgo)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
                
                // Last Message
                if let lastMessage = conversation.lastMessage {
                    Text(lastMessage)
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .lineSpacing(2)
                }
                
                // Status and Unread Badge
                HStack(spacing: 8) {
                    // Status Badge
                    HStack(spacing: 5) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 7, height: 7)
                        Text(conversation.status.capitalized)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(statusColor)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(statusColor.opacity(0.12))
                    )
                    
                    // Unread Badge
                    if conversation.unreadCount > 0 {
                        Text("\(conversation.unreadCount)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color(hex: "#4A6EE0"))  // Solid blue color
                            )
                    }
                    
                    Spacer()
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
    }
    
    private var channelColor: Color {
        switch conversation.channel {
        case "webchat": return Color(hex: "#3B82F6")
        case "whatsapp": return Color(hex: "#25D366")
        case "telegram": return Color(hex: "#0088CC")
        case "email": return Color(hex: "#6B7280")
        default: return .blue
        }
    }
    
    private var statusColor: Color {
        switch conversation.status {
        case "active": return Color(hex: "#10B981")
        case "pending": return Color(hex: "#F59E0B")
        case "resolved": return .gray
        case "closed": return Color(hex: "#EF4444")
        default: return .gray
        }
    }
}
