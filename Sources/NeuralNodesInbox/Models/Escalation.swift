import Foundation

/// Represents a live chat escalation
public struct Escalation: Codable, Identifiable {
    public let id: String
    public let leadId: String?
    public let leadName: String?
    public let leadEmail: String?
    public let status: String
    public let priority: String?
    public let unreadCount: Int?
    public let lastMessagePreview: String?
    public let conversationHistory: [ConversationHistoryItem]?
    public let lastMessageAt: Date?
    public let createdAt: Date
    public let updatedAt: Date
    public let resolvedAt: Date?
    public let resolutionNotes: String?
    // Everything below was missing from this model entirely - the JSON
    // response always included them (escalated_sessions.*, see
    // services/live_chat_service.py get_escalation/get_escalations), the
    // decoder just had nowhere to put them. assignedTo/assignedToName in
    // particular is ownership - the backend enforces "only the assigned
    // agent may send" (routes/live_chat_routes.py send_agent_message), so
    // without this the UI had no way to show who owns a chat or gate
    // claim-required actions.
    public let clientId: String?
    public let sessionId: String?
    public let assignedTo: String?
    public let assignedToName: String?
    public let escalationType: String?
    public let escalatedAt: Date?
    public let claimedAt: Date?
    public let lockExpiresAt: Date?

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
        case clientId = "client_id"
        case sessionId = "session_id"
        case assignedTo = "assigned_to"
        case assignedToName = "assigned_to_name"
        case escalationType = "escalation_type"
        case escalatedAt = "escalated_at"
        case claimedAt = "claimed_at"
        case lockExpiresAt = "lock_expires_at"
    }

    /// Display name for the escalation
    public var displayName: String {
        return leadName ?? leadEmail ?? "Anonymous Visitor"
    }

    /// Whether this escalation is currently assigned to an agent.
    public var isOwned: Bool { assignedTo != nil }
    
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
    let attachmentUrl: String?
    let attachmentType: String?
    let attachmentName: String?

    init(messageText: String, messageType: String = "text", attachmentUrl: String? = nil, attachmentType: String? = nil, attachmentName: String? = nil) {
        self.messageText = messageText
        self.messageType = messageType
        self.attachmentUrl = attachmentUrl
        self.attachmentType = attachmentType
        self.attachmentName = attachmentName
    }

    enum CodingKeys: String, CodingKey {
        case messageText = "message_text"
        case messageType = "message_type"
        case attachmentUrl = "attachment_url"
        case attachmentType = "attachment_type"
        case attachmentName = "attachment_name"
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

/// PusherService.send_escalation_status_change's "status-changed" payload.
public struct EscalationStatusChange: Codable {
    public let status: String
    public let assignedTo: String?
    public let assignedToName: String?

    enum CodingKeys: String, CodingKey {
        case status
        case assignedTo = "assigned_to"
        case assignedToName = "assigned_to_name"
    }
}

/// PusherService.send_agent_joined's "agent-joined" payload.
public struct AgentJoinedEvent: Codable {
    public let agentName: String
    public let agentId: String

    enum CodingKeys: String, CodingKey {
        case agentName = "agent_name"
        case agentId = "agent_id"
    }
}

/// PusherService.send_ownership_event's "ownership-changed" payload.
/// event is one of claimed/released/transferred/taken_over/reclaimed_stale.
public struct OwnershipChangedEvent: Codable {
    public let event: String
    public let newOwner: String?
    public let newOwnerName: String?
    public let previousOwner: String?

    enum CodingKeys: String, CodingKey {
        case event
        case newOwner = "new_owner"
        case newOwnerName = "new_owner_name"
        case previousOwner = "previous_owner"
    }
}

/// Body for POST /pusher/typing (routes/pusher_routes.py
/// send_typing_indicator) - unlike every other live-chat call,
/// escalation_id travels in the body here, not the URL path.
struct TypingIndicatorRequest: Codable {
    let escalationId: String
    let senderName: String
    let senderType: String
    let isTyping: Bool

    init(escalationId: String, senderName: String, senderType: String = "agent", isTyping: Bool) {
        self.escalationId = escalationId
        self.senderName = senderName
        self.senderType = senderType
        self.isTyping = isTyping
    }

    enum CodingKeys: String, CodingKey {
        case escalationId = "escalation_id"
        case senderName = "sender_name"
        case senderType = "sender_type"
        case isTyping = "is_typing"
    }
}

struct TakeoverRequest: Codable {
    let reason: String?
}

struct UploadAttachmentResponse: Codable {
    let success: Bool
    let attachmentUrl: String
    let attachmentType: String
    let attachmentName: String?

    enum CodingKeys: String, CodingKey {
        case success
        case attachmentUrl = "attachment_url"
        case attachmentType = "attachment_type"
        case attachmentName = "attachment_name"
    }
}
