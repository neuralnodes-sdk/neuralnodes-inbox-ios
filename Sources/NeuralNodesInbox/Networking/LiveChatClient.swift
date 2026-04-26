import Foundation

/// API client for live chat escalations
public class LiveChatClient {
    
    private let apiClient: APIClient
    
    public init(apiClient: APIClient) {
        self.apiClient = apiClient
    }
    
    // MARK: - Escalations
    
    public func getEscalations(status: String? = nil, limit: Int = 50, offset: Int = 0) async throws -> [Escalation] {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]
        
        if let status = status {
            queryItems.append(URLQueryItem(name: "status", value: status))
        }
        
        let response: EscalationsResponse = try await apiClient.request(
            path: "/client-portal/live-chat/escalations",
            method: "GET",
            queryItems: queryItems
        )
        return response.escalations
    }
    
    public func getEscalation(id: String) async throws -> Escalation {
        struct Response: Codable {
            let success: Bool
            let escalation: Escalation
        }
        let response: Response = try await apiClient.request(
            path: "/client-portal/live-chat/escalations/\(id)",
            method: "GET"
        )
        return response.escalation
    }
    
    // MARK: - Messages
    
    public func getEscalationMessages(escalationId: String, limit: Int = 100, offset: Int = 0) async throws -> [ChatMessage] {
        let queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]
        
        let response: ChatMessagesResponse = try await apiClient.request(
            path: "/client-portal/live-chat/escalations/\(escalationId)/messages",
            method: "GET",
            queryItems: queryItems
        )
        return response.messages
    }
    
    public func sendEscalationMessage(escalationId: String, text: String) async throws -> ChatMessage {
        let response: SendChatMessageResponse = try await apiClient.request(
            path: "/client-portal/live-chat/escalations/\(escalationId)/messages",
            method: "POST",
            body: SendChatMessageRequest(messageText: text, messageType: "text")
        )
        return response.message
    }
    
    public func markEscalationMessagesRead(escalationId: String) async throws {
        struct Response: Codable {
            let success: Bool
        }
        let _: Response = try await apiClient.request(
            path: "/client-portal/live-chat/escalations/\(escalationId)/mark-read",
            method: "POST"
        )
    }
    
    // MARK: - Escalation Management
    
    public func updateEscalationStatus(escalationId: String, status: String, resolutionNotes: String? = nil) async throws {
        struct Response: Codable {
            let success: Bool
        }
        let _: Response = try await apiClient.request(
            path: "/client-portal/live-chat/escalations/\(escalationId)/status",
            method: "PUT",
            body: UpdateEscalationStatusRequest(status: status, resolutionNotes: resolutionNotes)
        )
    }
    
    public func resolveEscalation(escalationId: String, notes: String? = nil) async throws {
        try await updateEscalationStatus(escalationId: escalationId, status: "resolved", resolutionNotes: notes)
    }
    
    public func endEscalation(escalationId: String, reason: String? = nil) async throws {
        try await updateEscalationStatus(escalationId: escalationId, status: "closed", resolutionNotes: reason ?? "Chat ended by agent")
    }
    
    public func transferEscalation(escalationId: String, toAgentId: String) async throws {
        struct Body: Codable {
            let agentId: String
            
            enum CodingKeys: String, CodingKey {
                case agentId = "agent_id"
            }
        }
        
        struct Response: Codable {
            let success: Bool
        }
        
        let _: Response = try await apiClient.request(
            path: "/client-portal/live-chat/escalations/\(escalationId)/transfer",
            method: "POST",
            body: Body(agentId: toAgentId)
        )
    }
    
    public func sendTypingIndicator(escalationId: String, isTyping: Bool) async throws {
        struct Response: Codable {
            let success: Bool
        }
        let _: Response = try await apiClient.request(
            path: "/client-portal/live-chat/escalations/\(escalationId)/typing",
            method: "POST",
            body: ["is_typing": isTyping]
        )
    }
}
