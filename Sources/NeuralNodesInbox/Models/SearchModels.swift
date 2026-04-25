import Foundation

// MARK: - Search Conversation Result

public struct SearchConversationResult: Codable, Identifiable {
    public let id: String
    public let clientId: String
    public let channel: String
    public let contactName: String?
    public let contactEmail: String?
    public let contactPhone: String?
    public let contactIdentifier: String?
    public let status: String
    public let priority: String
    public let unreadCount: Int
    public let messageCount: Int
    public let lastMessagePreview: String?
    public let lastMessageAt: Date?
    public let relevanceScore: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case clientId = "client_id"
        case channel
        case contactName = "contact_name"
        case contactEmail = "contact_email"
        case contactPhone = "contact_phone"
        case contactIdentifier = "contact_identifier"
        case status
        case priority
        case unreadCount = "unread_count"
        case messageCount = "message_count"
        case lastMessagePreview = "last_message_preview"
        case lastMessageAt = "last_message_at"
        case relevanceScore = "relevance_score"
    }
}

// MARK: - Search Message Result

public struct SearchMessageResult: Codable, Identifiable {
    public let id: String
    public let conversationId: String
    public let messageText: String
    public let senderType: String
    public let senderName: String?
    public let createdAt: Date
    public let matchedText: String?
    public let previousMessages: [MessageContext]?
    public let nextMessages: [MessageContext]?
    
    // Additional fields for global search
    public let contactName: String?
    public let contactEmail: String?
    public let contactPhone: String?
    public let contactIdentifier: String?
    public let channel: String?
    public let conversationStatus: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case messageText = "message_text"
        case senderType = "sender_type"
        case senderName = "sender_name"
        case createdAt = "created_at"
        case matchedText = "matched_text"
        case previousMessages = "previous_messages"
        case nextMessages = "next_messages"
        case contactName = "contact_name"
        case contactEmail = "contact_email"
        case contactPhone = "contact_phone"
        case contactIdentifier = "contact_identifier"
        case channel
        case conversationStatus = "conversation_status"
    }
}

public struct MessageContext: Codable, Identifiable {
    public let id: String
    public let messageText: String
    public let senderType: String
    public let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case messageText = "message_text"
        case senderType = "sender_type"
        case createdAt = "created_at"
    }
}

// MARK: - Search Response Wrappers

public struct SearchConversationsResponse: Codable {
    public let results: [SearchConversationResult]
    public let totalCount: Int
    public let pageSize: Int
    public let offset: Int
    public let hasMore: Bool
    public let error: String?
    
    enum CodingKeys: String, CodingKey {
        case results
        case totalCount = "total_count"
        case pageSize = "page_size"
        case offset
        case hasMore = "has_more"
        case error
    }
}

public struct SearchMessagesResponse: Codable {
    public let results: [SearchMessageResult]
    public let totalCount: Int
    public let pageSize: Int
    public let offset: Int
    public let hasMore: Bool
    
    enum CodingKeys: String, CodingKey {
        case results
        case totalCount = "total_count"
        case pageSize = "page_size"
        case offset
        case hasMore = "has_more"
    }
}

public struct SearchSuggestionsResponse: Codable {
    public let suggestions: [String]
}

// MARK: - Search Filters

public struct ConversationSearchFilters {
    public let query: String
    public let channel: String?
    public let status: String?
    public let limit: Int
    public let offset: Int
    
    public init(
        query: String,
        channel: String? = nil,
        status: String? = nil,
        limit: Int = 50,
        offset: Int = 0
    ) {
        self.query = query
        self.channel = channel
        self.status = status
        self.limit = limit
        self.offset = offset
    }
    
    func toQueryItems(clientId: String) -> [URLQueryItem] {
        var items = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]
        
        if let channel = channel {
            items.append(URLQueryItem(name: "channel", value: channel))
        }
        if let status = status {
            items.append(URLQueryItem(name: "status", value: status))
        }
        
        return items
    }
}

public struct MessageSearchFilters {
    public let query: String
    public let channel: String?
    public let senderType: String?
    public let dateFrom: Date?
    public let dateTo: Date?
    public let limit: Int
    public let offset: Int
    
    public init(
        query: String,
        channel: String? = nil,
        senderType: String? = nil,
        dateFrom: Date? = nil,
        dateTo: Date? = nil,
        limit: Int = 50,
        offset: Int = 0
    ) {
        self.query = query
        self.channel = channel
        self.senderType = senderType
        self.dateFrom = dateFrom
        self.dateTo = dateTo
        self.limit = limit
        self.offset = offset
    }
    
    func toQueryItems(clientId: String) -> [URLQueryItem] {
        var items = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]
        
        if let channel = channel {
            items.append(URLQueryItem(name: "channel", value: channel))
        }
        if let senderType = senderType {
            items.append(URLQueryItem(name: "sender_type", value: senderType))
        }
        
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime]
        
        if let dateFrom = dateFrom {
            items.append(URLQueryItem(name: "date_from", value: iso8601Formatter.string(from: dateFrom)))
        }
        if let dateTo = dateTo {
            items.append(URLQueryItem(name: "date_to", value: iso8601Formatter.string(from: dateTo)))
        }
        
        return items
    }
}
