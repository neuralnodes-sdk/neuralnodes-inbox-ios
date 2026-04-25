import SwiftUI

// Protocol for message types
public protocol MessageProtocol {
    var id: String { get }
    var messageText: String { get }
    var senderType: String { get }
    var senderName: String? { get }
    var createdAt: Date { get }
    var isFromUser: Bool { get }
    var isFromAgent: Bool { get }
    var displaySenderName: String { get }
}

// Extend Message to conform to protocol
extension Message: MessageProtocol {}

// Extend ChatMessage to conform to protocol
extension ChatMessage: MessageProtocol {}

public struct MessageBubble<T: MessageProtocol>: View {
    let message: T
    @Environment(\.colorScheme) var colorScheme
    
    public init(message: T) {
        self.message = message
    }
    
    private var isSystemMessage: Bool {
        message.senderType == "system"
    }
    
    public var body: some View {
        if isSystemMessage {
            // System message - centered
            VStack(spacing: 4) {
                Text(message.messageText)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        (colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6))
                            .opacity(0.8)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                
                // Centered timestamp for system messages
                Text(formattedTime)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
        } else {
            // Regular message - left or right aligned
            HStack(alignment: .bottom, spacing: 0) {
                if message.isFromAgent {
                    Spacer(minLength: 60)
                }
                
                VStack(alignment: message.isFromAgent ? .trailing : .leading, spacing: 4) {
                    // Sender Name (for user messages)
                    if message.isFromUser {
                        Text(message.displaySenderName)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                    }
                    
                    // Message Bubble
                    Text(message.messageText)
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundColor(message.isFromAgent ? .white : (colorScheme == .dark ? .white : .primary))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            Group {
                                if message.isFromAgent {
                                    LinearGradient(
                                        colors: [Color(hex: "#667eea"), Color(hex: "#764ba2")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                } else {
                                    (colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6))
                                }
                            }
                        )
                        .clipShape(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                        )
                        .shadow(
                            color: message.isFromAgent
                                ? Color(hex: "#667eea").opacity(0.3)
                                : Color.black.opacity(colorScheme == .dark ? 0.3 : 0.08),
                            radius: 8,
                            x: 0,
                            y: 2
                        )
                    
                    // Timestamp
                    Text(formattedTime)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.8))
                        .padding(.horizontal, 16)
                        .padding(.top, 2)
                }
                
                if message.isFromUser {
                    Spacer(minLength: 60)
                }
            }
        }
    }
    
    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: message.createdAt)
    }
}
