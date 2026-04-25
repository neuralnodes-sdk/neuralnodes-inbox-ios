import Foundation

/// HTTP API client for NeuralNodes backend
public class APIClient {
    
    private let apiKey: String
    private let baseURL: String
    private let session: URLSession
    
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        // Custom date decoding to handle various formats including microseconds and timezones
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // Try ISO8601DateFormatter first (handles fractional seconds and timezones)
            if #available(iOS 11.0, *) {
                let iso8601Formatter = ISO8601DateFormatter()
                
                // Try with fractional seconds and timezone
                iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = iso8601Formatter.date(from: dateString) {
                    return date
                }
                
                // Try without fractional seconds but with timezone
                iso8601Formatter.formatOptions = [.withInternetDateTime]
                if let date = iso8601Formatter.date(from: dateString) {
                    return date
                }
                
                // Try with fractional seconds but without timezone
                iso8601Formatter.formatOptions = [.withFullDate, .withFullTime, .withFractionalSeconds, .withDashSeparatorInDate, .withColonSeparatorInTime]
                if let date = iso8601Formatter.date(from: dateString) {
                    return date
                }
            }
            
            // Fallback to DateFormatter for custom formats
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            
            let formats = [
                "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ",  // With microseconds and timezone
                "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",       // With microseconds, no timezone
                "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ",     // With milliseconds and timezone
                "yyyy-MM-dd'T'HH:mm:ss.SSS",          // With milliseconds, no timezone
                "yyyy-MM-dd'T'HH:mm:ssZZZZZ",         // No fractional seconds, with timezone
                "yyyy-MM-dd'T'HH:mm:ss"               // No fractional seconds, no timezone
            ]
            
            for format in formats {
                formatter.dateFormat = format
                if let date = formatter.date(from: dateString) {
                    return date
                }
            }
            
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string: \(dateString)")
        }
        
        return decoder
    }()
    
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    
    public init(apiKey: String, baseURL: String = "https://api.neuralnodes.space") {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.session = URLSession.shared
    }
    
    // MARK: - SDK Configuration
    
    public func getConfig() async throws -> SDKConfig {
        let response: SDKConfigResponse = try await request(
            path: "/sdk/config",
            method: "GET"
        )
        return response.config
    }
    
    // MARK: - Conversations
    
    public func getConversations(filters: ConversationFilters = ConversationFilters()) async throws -> [Conversation] {
        let response: ConversationsResponse = try await request(
            path: "/client-portal/inbox/conversations",
            method: "GET",
            queryItems: filters.toQueryItems()
        )
        return response.conversations
    }
    
    public func getConversation(id: String) async throws -> Conversation {
        struct Response: Codable {
            let success: Bool
            let conversation: Conversation
        }
        let response: Response = try await request(
            path: "/client-portal/inbox/conversations/\(id)",
            method: "GET"
        )
        return response.conversation
    }
    
    // MARK: - Messages
    
    public func getMessages(conversationId: String, limit: Int = 100, offset: Int = 0) async throws -> [Message] {
        let queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]
        
        let response: MessagesResponse = try await request(
            path: "/client-portal/inbox/conversations/\(conversationId)/messages",
            method: "GET",
            queryItems: queryItems
        )
        return response.messages
    }
    
    public func sendMessage(conversationId: String, text: String, attachmentUrl: String? = nil) async throws -> Message {
        let body = SendMessageRequest(
            messageText: text,
            messageType: attachmentUrl != nil ? "image" : "text",
            attachmentUrl: attachmentUrl,
            attachmentType: attachmentUrl != nil ? "image" : nil,
            attachmentName: nil
        )
        
        let response: SendMessageResponse = try await request(
            path: "/client-portal/inbox/conversations/\(conversationId)/messages",
            method: "POST",
            body: body
        )
        return response.message
    }
    
    public func markAsRead(conversationId: String) async throws {
        struct Response: Codable {
            let success: Bool
        }
        let _: Response = try await request(
            path: "/client-portal/inbox/conversations/\(conversationId)/mark-read",
            method: "POST"
        )
    }
    
    // MARK: - Conversation Management
    
    public func updateStatus(conversationId: String, status: String) async throws {
        struct Body: Codable {
            let status: String
        }
        struct Response: Codable {
            let success: Bool
        }
        let _: Response = try await request(
            path: "/client-portal/inbox/conversations/\(conversationId)/status",
            method: "PUT",
            body: Body(status: status)
        )
    }
    
    // MARK: - Device Registration
    
    public func registerDevice(token: String, platform: String, deviceInfo: [String: Any] = [:]) async throws {
        struct Response: Codable {
            let success: Bool
        }
        
        // Convert device info to JSON string
        let deviceInfoJson: String
        if !deviceInfo.isEmpty {
            let jsonData = try JSONSerialization.data(withJSONObject: deviceInfo, options: [])
            deviceInfoJson = String(data: jsonData, encoding: .utf8) ?? "{}"
        } else {
            deviceInfoJson = "{}"
        }
        
        // Send as query parameters (matching Android implementation)
        let queryItems = [
            URLQueryItem(name: "device_token", value: token),
            URLQueryItem(name: "platform", value: platform),
            URLQueryItem(name: "device_info", value: deviceInfoJson)
        ]
        
        let _: Response = try await request(
            path: "/sdk/register-device",
            method: "POST",
            queryItems: queryItems
        )
    }
    
    // MARK: - Generic Request
    
    public func request<T: Decodable>(
        path: String,
        method: String,
        queryItems: [URLQueryItem]? = nil,
        body: Encodable? = nil
    ) async throws -> T {
        var urlComponents = URLComponents(string: baseURL + path)!
        urlComponents.queryItems = queryItems
        
        guard let url = urlComponents.url else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SDKVersion.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(SDKVersion.version, forHTTPHeaderField: "X-SDK-Version")
        request.setValue("iOS", forHTTPHeaderField: "X-SDK-Platform")
        
        if let body = body {
            request.httpBody = try encoder.encode(body)
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
        
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
}

// MARK: - API Errors

public enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(Error)
    case networkError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
