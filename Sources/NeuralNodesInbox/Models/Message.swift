import Foundation

/// Represents a message in a conversation
public struct Message: Codable, Identifiable {
    public let id: String
    public let conversationId: String
    public let messageType: String
    public let messageText: String
    public let senderType: String
    public let senderName: String?
    public let senderId: String?
    public let attachmentUrl: String?
    public let attachmentType: String?
    public let attachmentName: String?
    public let isRead: Bool
    public let createdAt: Date
    
    public init(
        id: String,
        conversationId: String,
        messageType: String,
        messageText: String,
        senderType: String,
        senderName: String?,
        senderId: String?,
        attachmentUrl: String?,
        attachmentType: String?,
        attachmentName: String?,
        isRead: Bool,
        createdAt: Date
    ) {
        self.id = id
        self.conversationId = conversationId
        self.messageType = messageType
        self.messageText = messageText
        self.senderType = senderType
        self.senderName = senderName
        self.senderId = senderId
        self.attachmentUrl = attachmentUrl
        self.attachmentType = attachmentType
        self.attachmentName = attachmentName
        self.isRead = isRead
        self.createdAt = createdAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case messageType = "message_type"
        case messageText = "message_text"
        case senderType = "sender_type"
        case senderName = "sender_name"
        case senderId = "sender_id"
        case attachmentUrl = "attachment_url"
        case attachmentType = "attachment_type"
        case attachmentName = "attachment_name"
        case isRead = "is_read"
        case createdAt = "created_at"
    }
    
    /// Whether this message is from the user (not agent)
    public var isFromUser: Bool {
        return senderType == "user"
    }
    
    /// Whether this message is from an agent
    public var isFromAgent: Bool {
        return senderType == "agent"
    }
    
    /// Display name for the sender
    public var displaySenderName: String {
        return senderName ?? (isFromUser ? "User" : "Agent")
    }
}

/// Response wrapper for messages list
struct MessagesResponse: Codable {
    let success: Bool
    let messages: [Message]
    let count: Int
}

/// Request body for sending a message
struct SendMessageRequest: Codable {
    let messageText: String
    let messageType: String
    let attachmentUrl: String?
    let attachmentType: String?
    let attachmentName: String?
    
    enum CodingKeys: String, CodingKey {
        case messageText = "message_text"
        case messageType = "message_type"
        case attachmentUrl = "attachment_url"
        case attachmentType = "attachment_type"
        case attachmentName = "attachment_name"
    }
}

/// Response wrapper for sending a message
struct SendMessageResponse: Codable {
    let success: Bool
    let message: Message
}
