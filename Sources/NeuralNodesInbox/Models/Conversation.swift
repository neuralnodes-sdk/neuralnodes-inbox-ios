import Foundation

/// Represents a conversation in the inbox
public struct Conversation: Codable, Identifiable {
    public let id: String
    public let channel: String
    public let contactName: String?
    public let contactEmail: String?
    public let contactPhone: String?
    public let lastMessagePreview: String?
    public let unreadCount: Int
    public let status: String
    public let lastMessageAt: Date?
    public let createdAt: Date
    public let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case channel
        case contactName = "contact_name"
        case contactEmail = "contact_email"
        case contactPhone = "contact_phone"
        case lastMessagePreview = "last_message_preview"
        case unreadCount = "unread_count"
        case status
        case lastMessageAt = "last_message_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    /// Display name for the conversation
    public var displayName: String {
        return contactName ?? contactEmail ?? contactPhone ?? "Unknown"
    }
    
    /// Last message for display (alias for lastMessagePreview)
    public var lastMessage: String? {
        return lastMessagePreview
    }
}

/// Response wrapper for conversations list
struct ConversationsResponse: Codable {
    let success: Bool
    let conversations: [Conversation]
    let count: Int
}

/// Filters for conversation queries
public struct ConversationFilters {
    public let channel: String?
    public let status: String?
    public let assignedTo: String?
    public let limit: Int
    public let offset: Int
    
    public init(
        channel: String? = nil,
        status: String? = nil,
        assignedTo: String? = nil,
        limit: Int = 50,
        offset: Int = 0
    ) {
        self.channel = channel
        self.status = status
        self.assignedTo = assignedTo
        self.limit = limit
        self.offset = offset
    }
    
    /// Convert to URL query parameters
    func toQueryItems() -> [URLQueryItem] {
        var items: [URLQueryItem] = []
        
        if let channel = channel {
            items.append(URLQueryItem(name: "channel", value: channel))
        }
        if let status = status {
            items.append(URLQueryItem(name: "status", value: status))
        }
        if let assignedTo = assignedTo {
            items.append(URLQueryItem(name: "assigned_to", value: assignedTo))
        }
        items.append(URLQueryItem(name: "limit", value: "\(limit)"))
        items.append(URLQueryItem(name: "offset", value: "\(offset)"))
        
        return items
    }
}
