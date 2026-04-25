import SwiftUI

public struct FilterBar: View {
    @Binding var selectedChannel: Channel
    @Binding var selectedStatus: ConversationStatus
    let onChannelTap: () -> Void
    let onStatusTap: () -> Void
    
    public init(
        selectedChannel: Binding<Channel>,
        selectedStatus: Binding<ConversationStatus>,
        onChannelTap: @escaping () -> Void,
        onStatusTap: @escaping () -> Void
    ) {
        self._selectedChannel = selectedChannel
        self._selectedStatus = selectedStatus
        self.onChannelTap = onChannelTap
        self.onStatusTap = onStatusTap
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            // Channel Filter
            FilterButton(
                icon: selectedChannel.icon,
                title: selectedChannel.displayName,
                color: selectedChannel.color,
                action: onChannelTap
            )
            
            // Status Filter
            FilterButton(
                icon: selectedStatus.icon,
                title: selectedStatus.displayName,
                color: selectedStatus.color,
                action: onStatusTap
            )
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

public struct FilterButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    public init(icon: String, title: String, color: Color, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.color = color
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
            }
            .foregroundColor(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(color.opacity(0.1))
            .cornerRadius(8)
        }
    }
}
