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
    
    // Was POST .../messages - that path was never registered on the
    // backend (only .../messages/agent and .../messages/user exist), so
    // every agent send from this SDK 404'd. This SDK only ever sends as
    // the agent, so .../messages/agent is the correct, and only correct,
    // endpoint here.
    public func sendEscalationMessage(escalationId: String, text: String, attachmentUrl: String? = nil, attachmentType: String? = nil, attachmentName: String? = nil) async throws -> ChatMessage {
        let response: SendChatMessageResponse = try await apiClient.request(
            path: "/client-portal/live-chat/escalations/\(escalationId)/messages/agent",
            method: "POST",
            body: SendChatMessageRequest(messageText: text, attachmentUrl: attachmentUrl, attachmentType: attachmentType, attachmentName: attachmentName)
        )
        return response.message
    }

    // Was POST .../mark-read - also never registered; the real path is
    // .../messages/read.
    public func markEscalationMessagesRead(escalationId: String) async throws {
        struct Response: Codable {
            let success: Bool
        }
        let _: Response = try await apiClient.request(
            path: "/client-portal/live-chat/escalations/\(escalationId)/messages/read",
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
    
    // Was POST .../escalations/{id}/typing - no such path exists anywhere
    // on the backend, so this always 404'd. The one real typing endpoint
    // is POST /pusher/typing (routes/pusher_routes.py), a flat path that
    // takes escalation_id in the body rather than as a URL path segment.
    public func sendTypingIndicator(escalationId: String, isTyping: Bool, senderName: String = "Agent") async throws {
        struct Response: Codable {
            let success: Bool
        }
        let _: Response = try await apiClient.request(
            path: "/pusher/typing",
            method: "POST",
            body: TypingIndicatorRequest(escalationId: escalationId, senderName: senderName, isTyping: isTyping)
        )
    }

    // MARK: - Ownership

    // Sending a message requires owning the escalation first unless
    // authenticated with a bare client API key (see
    // routes/live_chat_routes.py send_agent_message's ownership gate) -
    // none of these were ever called anywhere in this SDK before.

    /// Claims an unowned escalation. Throws APIError.httpError(409, _) if
    /// someone else already claimed it first.
    public func claimEscalation(escalationId: String) async throws -> Escalation {
        struct Response: Codable { let success: Bool; let escalation: Escalation }
        let response: Response = try await apiClient.request(
            path: "/client-portal/live-chat/escalations/\(escalationId)/claim",
            method: "POST"
        )
        return response.escalation
    }

    public func releaseEscalation(escalationId: String) async throws {
        struct Response: Codable { let success: Bool }
        let _: Response = try await apiClient.request(
            path: "/client-portal/live-chat/escalations/\(escalationId)/release",
            method: "POST"
        )
    }

    /// Supervisor/admin override of the current owner.
    public func takeoverEscalation(escalationId: String, reason: String? = nil) async throws -> Escalation {
        struct Response: Codable { let success: Bool; let escalation: Escalation }
        let response: Response = try await apiClient.request(
            path: "/client-portal/live-chat/escalations/\(escalationId)/takeover",
            method: "POST",
            body: TakeoverRequest(reason: reason)
        )
        return response.escalation
    }

    /// Extends the ownership lease - call every ~30s while a chat is open.
    /// Throws APIError.httpError(409, _) if ownership was lost.
    public func sendHeartbeat(escalationId: String) async throws {
        struct Response: Codable { let success: Bool }
        let _: Response = try await apiClient.request(
            path: "/client-portal/live-chat/escalations/\(escalationId)/heartbeat",
            method: "POST"
        )
    }

    // MARK: - Attachments

    /// Uploads a file for this escalation and sends it as a message in one
    /// call - nothing in this SDK could attach a file to a live-chat
    /// message before this.
    public func sendAttachment(escalationId: String, filename: String, mimeType: String, data: Data, caption: String? = nil) async throws -> ChatMessage {
        let uploaded = try await apiClient.uploadAgentAttachment(escalationId: escalationId, filename: filename, mimeType: mimeType, data: data)
        return try await sendEscalationMessage(
            escalationId: escalationId,
            text: caption ?? "",
            attachmentUrl: uploaded.attachmentUrl,
            attachmentType: uploaded.attachmentType,
            attachmentName: uploaded.attachmentName
        )
    }
}
