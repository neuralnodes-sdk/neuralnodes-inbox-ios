import Foundation

/// SDK Configuration from backend
public struct SDKConfig: Codable {
    public let enabled: Bool
    public let ablyKey: String?
    public let pusherKey: String?
    public let pusherCluster: String?
    public let apiBaseURL: String
    public let features: Features
    public let branding: Branding
    public let limits: Limits
    
    public struct Features: Codable {
        public let darkMode: Bool
        public let pushNotifications: Bool
        public let fileUpload: Bool
        public let voiceMessages: Bool
        public let videoMessages: Bool
        public let typingIndicators: Bool
        public let readReceipts: Bool
        public let conversationSearch: Bool
        
        enum CodingKeys: String, CodingKey {
            case darkMode = "dark_mode"
            case pushNotifications = "push_notifications"
            case fileUpload = "file_upload"
            case voiceMessages = "voice_messages"
            case videoMessages = "video_messages"
            case typingIndicators = "typing_indicators"
            case readReceipts = "read_receipts"
            case conversationSearch = "conversation_search"
        }
    }
    
    public struct Branding: Codable {
        public let primaryColor: String
        public let logoURL: String?
        
        enum CodingKeys: String, CodingKey {
            case primaryColor = "primary_color"
            case logoURL = "logo_url"
        }
    }
    
    public struct Limits: Codable {
        public let maxFileSizeMB: Int
        public let maxMessageLength: Int
        public let messagesPerPage: Int
        public let maxConversationsCache: Int
        
        enum CodingKeys: String, CodingKey {
            case maxFileSizeMB = "max_file_size_mb"
            case maxMessageLength = "max_message_length"
            case messagesPerPage = "messages_per_page"
            case maxConversationsCache = "max_conversations_cache"
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case enabled
        case ablyKey = "ably_key"
        case pusherKey = "pusher_key"
        case pusherCluster = "pusher_cluster"
        case apiBaseURL = "api_base_url"
        case features
        case branding
        case limits
    }
}

/// Response wrapper for SDK config
struct SDKConfigResponse: Codable {
    let success: Bool
    let clientId: String
    let config: SDKConfig
    
    enum CodingKeys: String, CodingKey {
        case success
        case clientId = "client_id"
        case config
    }
}
