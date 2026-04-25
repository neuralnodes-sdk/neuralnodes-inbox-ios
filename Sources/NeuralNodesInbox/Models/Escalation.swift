import Foundation

/// Represents a live chat escalation
public struct Escalation: Codable, Identifiable {
    public let id: String
    public let leadId: String?
    public let leadName: String?
    public let leadEmail: String?
    public let status: String
    public let priority: String?
    public let unreadCount: Int
    public let lastMessagePreview: String?
    public let conversationHistory: [ConversationHistoryItem]?
    public let lastMessageAt: Date?
    public let createdAt: Date
    public let updatedAt: Date
    public let resolvedAt: Date?
    public let resolutionNotes: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case leadId = "lead_id"
        case leadName = "lead_name"
        case leadEmail = "lead_email"
        case status
        case priority
        case unreadCount = "unread_count"
        case lastMessagePreview = "last_message_preview"
        case conversationHistory = "conversation_history"
        case lastMessageAt = "last_message_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case resolvedAt = "resolved_at"
        case resolutionNotes = "resolution_notes"
    }
    
    /// Display name for the escalation
    public var displayName: String {
        return leadName ?? leadEmail ?? "Anonymous Visitor"
    }
    
    /// Whether the escalation is active
    public var isActive: Bool {
        return status == "active"
    }
    
    /// Whether the escalation is pending
    public var isPending: Bool {
        return status == "pending"
    }
    
    /// Whether the escalation is resolved
    public var isResolved: Bool {
        return status == "resolved" || status == "closed"
    }
}

/// Conversation history item from bot chat
public struct ConversationHistoryItem: Codable {
    public let text: String
    public let type: String
    public let sender: String
    public let timestamp: String
}

/// Response wrapper for escalations list
struct EscalationsResponse: Codable {
    let success: Bool
    let escalations: [Escalation]
    let count: Int
}

/// Chat message for live chat escalations
public struct ChatMessage: Codable, Identifiable {
    public let id: String
    public let escalationId: String
    public let messageType: String
    public let messageText: String
    public let senderType: String
    public let senderName: String?
    public let senderId: String?
    public let attachmentUrl: String?
    public let attachmentType: String?
    public let attachmentName: String?
    public let isRead: Bool
    public let readAt: Date?
    public let createdAt: Date
    
    public init(
        id: String,
        escalationId: String,
        messageType: String,
        messageText: String,
        senderType: String,
        senderName: String?,
        senderId: String?,
        attachmentUrl: String?,
        attachmentType: String?,
        attachmentName: String?,
        isRead: Bool,
        readAt: Date?,
        createdAt: Date
    ) {
        self.id = id
        self.escalationId = escalationId
        self.messageType = messageType
        self.messageText = messageText
        self.senderType = senderType
        self.senderName = senderName
        self.senderId = senderId
        self.attachmentUrl = attachmentUrl
        self.attachmentType = attachmentType
        self.attachmentName = attachmentName
        self.isRead = isRead
        self.readAt = readAt
        self.createdAt = createdAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case escalationId = "escalation_id"
        case messageType = "message_type"
        case messageText = "message_text"
        case senderType = "sender_type"
        case senderName = "sender_name"
        case senderId = "sender_id"
        case attachmentUrl = "attachment_url"
        case attachmentType = "attachment_type"
        case attachmentName = "attachment_name"
        case isRead = "is_read"
        case readAt = "read_at"
        case createdAt = "created_at"
    }
    
    /// Whether this message is from the user (visitor)
    public var isFromUser: Bool {
        return senderType == "user"
    }
    
    /// Whether this message is from an agent
    public var isFromAgent: Bool {
        return senderType == "agent"
    }
    
    /// Display name for the sender
    public var displaySenderName: String {
        return senderName ?? (isFromUser ? "Visitor" : "Agent")
    }
}

/// Response wrapper for chat messages list
struct ChatMessagesResponse: Codable {
    let success: Bool
    let messages: [ChatMessage]
    let count: Int
}

/// Request body for sending a chat message
struct SendChatMessageRequest: Codable {
    let messageText: String
    let messageType: String
    
    enum CodingKeys: String, CodingKey {
        case messageText = "message_text"
        case messageType = "message_type"
    }
}

/// Response wrapper for sending a chat message
struct SendChatMessageResponse: Codable {
    let success: Bool
    let message: ChatMessage
}

/// Request body for updating escalation status
struct UpdateEscalationStatusRequest: Codable {
    let status: String
    let resolutionNotes: String?
    
    enum CodingKeys: String, CodingKey {
        case status
        case resolutionNotes = "resolution_notes"
    }
}
