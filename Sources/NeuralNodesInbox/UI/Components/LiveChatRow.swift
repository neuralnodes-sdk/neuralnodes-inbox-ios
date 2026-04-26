import SwiftUI

public struct LiveChatRow: View {
    let escalation: Escalation
    
    public init(escalation: Escalation) {
        self.escalation = escalation
    }
    
    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.primaryPurple.opacity(0.1))
                    .frame(width: 50, height: 50)
                
                Text(initials(from: escalation.leadName ?? "Unknown"))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primaryPurple)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                // Name and Time
                HStack {
                    Text(escalation.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(timeAgo(from: escalation.createdAt))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                // Last message preview
                if let preview = escalation.lastMessagePreview {
                    Text(preview)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                // Status and Unread
                HStack(spacing: 8) {
                    // Status Badge
                    HStack(spacing: 4) {
                        Circle()
                            .fill(statusColor(escalation.status))
                            .frame(width: 6, height: 6)
                        Text(escalation.status.capitalized)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(statusColor(escalation.status))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor(escalation.status).opacity(0.1))
                    .cornerRadius(6)
                    
                    // Unread Badge
                    if let unreadCount = escalation.unreadCount, unreadCount > 0 {
                        Text("\(unreadCount)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.errorRed)
                            .cornerRadius(10)
                    }
                    
                    Spacer()
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func initials(from name: String) -> String {
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return "\(components[0].prefix(1))\(components[1].prefix(1))".uppercased()
        } else if let first = components.first {
            return String(first.prefix(2)).uppercased()
        }
        return "?"
    }
    
    private func statusColor(_ status: String) -> Color {
        switch status {
        case "active": return .successGreen
        case "waiting": return .warningYellow
        default: return .gray
        }
    }
    
    private func timeAgo(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        
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
