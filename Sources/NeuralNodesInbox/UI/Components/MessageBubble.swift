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
    let searchText: String?
    let isHighlighted: Bool
    @Environment(\.colorScheme) var colorScheme
    
    public init(message: T, searchText: String? = nil, isHighlighted: Bool = false) {
        self.message = message
        self.searchText = searchText
        self.isHighlighted = isHighlighted
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
                    messageTextView
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            Group {
                                if message.isFromAgent {
                                    Color(hex: "#4A6EE0")  // Solid blue color instead of gradient
                                } else {
                                    (colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6))
                                }
                            }
                        )
                        .clipShape(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                        )
                        .overlay(
                            // Highlight border when this is the current search result
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(isHighlighted ? Color.yellow : Color.clear, lineWidth: 3)
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
    
    /// Message text with search highlighting
    @ViewBuilder
    private var messageTextView: some View {
        if let searchText = searchText, !searchText.isEmpty {
            highlightedText(text: message.messageText, highlight: searchText)
                .font(.system(size: 16, weight: .regular, design: .rounded))
        } else {
            Text(message.messageText)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundColor(message.isFromAgent ? .white : (colorScheme == .dark ? .white : .primary))
        }
    }
    
    /// Create attributed text with highlighted search terms
    private func highlightedText(text: String, highlight: String) -> Text {
        let lowercasedText = text.lowercased()
        let lowercasedHighlight = highlight.lowercased()
        
        var result = Text("")
        var currentIndex = text.startIndex
        
        while currentIndex < text.endIndex {
            // Find next occurrence of search term
            if let range = lowercasedText.range(of: lowercasedHighlight, range: currentIndex..<text.endIndex) {
                // Add text before match
                if currentIndex < range.lowerBound {
                    let beforeText = String(text[currentIndex..<range.lowerBound])
                    result = result + Text(beforeText)
                        .foregroundColor(message.isFromAgent ? .white : (colorScheme == .dark ? .white : .primary))
                }
                
                // Add highlighted match (yellow text with bold weight)
                let matchText = String(text[range])
                result = result + Text(matchText)
                    .fontWeight(.bold)
                    .foregroundColor(.yellow)
                
                currentIndex = range.upperBound
            } else {
                // No more matches, add remaining text
                let remainingText = String(text[currentIndex..<text.endIndex])
                result = result + Text(remainingText)
                    .foregroundColor(message.isFromAgent ? .white : (colorScheme == .dark ? .white : .primary))
                break
            }
        }
        
        return result
    }
}
