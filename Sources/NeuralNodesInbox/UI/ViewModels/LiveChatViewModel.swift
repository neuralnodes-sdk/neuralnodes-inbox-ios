import SwiftUI
import Combine

@MainActor
public class LiveChatViewModel: ObservableObject {
    @Published public var messages: [ChatMessage] = []
    @Published public var messageText: String = ""
    @Published public var isConnected = true
    @Published public var isTyping = false
    @Published public var isSending = false
    @Published public var isLoadingMore = false
    @Published public var hasMoreMessages = true
    @Published public var scrollToMessageId: String?
    @Published public var currentStatus: String
    // One-shot realtime notices for the UI to surface (toast/banner) and
    // clear - nil means "nothing pending". Neither event was reachable
    // before: the backend has always sent them, but nothing subscribed.
    @Published public var agentJoinedEvent: AgentJoinedEvent?
    @Published public var ownershipEvent: OwnershipChangedEvent?

    public let escalationId: String
    private let sdk: NeuralNodesInbox
    private let pageSize = 15
    private var currentOffset = 0
    private var isInitialLoad = true
    private var heartbeatTask: Task<Void, Never>?

    public init(escalationId: String, sdk: NeuralNodesInbox) {
        self.escalationId = escalationId
        self.sdk = sdk
        self.currentStatus = "active" // Default, will be updated when loading
    }

    /// True once ownershipEvent has told us someone else now owns the
    /// chat (taken over, or claimed by another agent) - the composer
    /// should disable and the caller should stop sending.
    public var ownershipLost: Bool {
        guard let event = ownershipEvent,
              ["taken_over", "claimed", "transferred"].contains(event.event) else { return false }
        return event.newOwner != sdk.currentAgent?.id
    }

    public func connect() async {
        do {
            try await Task.sleep(nanoseconds: 500_000_000)
            isConnected = true

            // Subscribe to Pusher channel
            let pusherClient = sdk.getPusherClient()
            pusherClient.subscribeToEscalation(escalationId, onMessage: { [weak self] message in
                print("📬 [LIVE CHAT VM] Received message from Pusher: \(message.messageText)")
                Task { @MainActor in
                    guard let self = self else { return }

                    print("🔍 [LIVE CHAT VM] Checking for duplicates...")

                    // Check if message already exists by ID
                    if self.messages.contains(where: { $0.id == message.id }) {
                        print("⚠️ [LIVE CHAT VM] Message with ID \(message.id) already exists, skipping")
                        return
                    }

                    // Also check for duplicates by content and timestamp (within 2 seconds)
                    // This handles the case where we sent the message and it comes back via Pusher
                    let isDuplicate = self.messages.contains { existingMsg in
                        existingMsg.messageText == message.messageText &&
                        existingMsg.senderType == message.senderType &&
                        abs(existingMsg.createdAt.timeIntervalSince(message.createdAt)) < 2.0
                    }

                    if isDuplicate {
                        print("⚠️ [LIVE CHAT VM] Duplicate message detected by content/timestamp, skipping")
                        return
                    }

                    print("➕ [LIVE CHAT VM] Adding message to list")
                    self.messages.append(message)
                    self.scrollToMessageId = message.id
                    print("✅ [LIVE CHAT VM] Message added, total messages: \(self.messages.count)")
                }
            }, onTyping: { [weak self] isTyping in
                Task { @MainActor in
                    self?.isTyping = isTyping
                }
            }, onStatusChanged: { [weak self] change in
                Task { @MainActor in
                    self?.currentStatus = change.status
                }
            }, onAgentJoined: { [weak self] event in
                Task { @MainActor in
                    self?.agentJoinedEvent = event
                }
            }, onOwnershipChanged: { [weak self] event in
                Task { @MainActor in
                    guard let self else { return }
                    self.ownershipEvent = event
                    if self.ownershipLost { self.stopHeartbeat() }
                }
            })

            startHeartbeat()
        } catch {
            isConnected = false
        }
    }

    /// Claims this escalation for the current agent. Call before
    /// sendMessage() on an unowned chat - the backend rejects a send from
    /// anyone but the assigned owner.
    public func claim() async {
        do {
            _ = try await sdk.getLiveChatClient().claimEscalation(escalationId: escalationId)
            currentStatus = "active"
        } catch {
            print("❌ [LIVE CHAT VM] Failed to claim escalation: \(error)")
        }
    }

    /// Extends the ownership lease every 30s while this chat is open -
    /// required for the owner to stay the owner (see
    /// routes/live_chat_routes.py heartbeat_escalation_route: the lease
    /// expires after 5 minutes idle). Never called anywhere in this SDK
    /// before this.
    private func startHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                guard let self, !Task.isCancelled else { return }
                do {
                    try await self.sdk.getLiveChatClient().sendHeartbeat(escalationId: self.escalationId)
                } catch {
                    print("⚠️ [LIVE CHAT VM] Heartbeat failed (ownership likely lost): \(error)")
                }
            }
        }
    }

    private func stopHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
    }

    public func disconnect() {
        stopHeartbeat()
        let pusherClient = sdk.getPusherClient()
        pusherClient.unsubscribe(from: escalationId)
        isConnected = false
    }
    
    public func loadMessages() async {
        print("📥 [LIVE CHAT VM] loadMessages started for escalation: \(escalationId)")
        currentOffset = 0
        hasMoreMessages = true
        isInitialLoad = true
        
        do {
            let liveChatClient = sdk.getLiveChatClient()
            
            // Load escalation details to get current status
            print("🌐 [LIVE CHAT VM] Fetching escalation details...")
            let escalation = try await liveChatClient.getEscalation(id: escalationId)
            currentStatus = escalation.status
            print("✅ [LIVE CHAT VM] Escalation status: \(currentStatus)")
            
            print("🌐 [LIVE CHAT VM] Fetching messages...")
            let fetchedMessages = try await liveChatClient.getEscalationMessages(
                escalationId: escalationId,
                limit: pageSize,
                offset: currentOffset
            )
            
            print("✅ [LIVE CHAT VM] Received \(fetchedMessages.count) messages")
            messages = fetchedMessages.sorted { $0.createdAt < $1.createdAt }
            hasMoreMessages = fetchedMessages.count == pageSize
            currentOffset = pageSize
            
            // Mark messages as read
            print("📖 [LIVE CHAT VM] Marking messages as read...")
            try? await liveChatClient.markEscalationMessagesRead(escalationId: escalationId)
            print("✅ [LIVE CHAT VM] Messages marked as read")
            
            // Scroll to bottom after messages loaded
            if let lastMessage = messages.last {
                scrollToMessageId = lastMessage.id
                print("📜 [LIVE CHAT VM] Scrolling to last message: \(lastMessage.id)")
            }
            
            // Mark as no longer initial load after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.isInitialLoad = false
            }
        } catch {
            print("❌ [LIVE CHAT VM] Error loading messages: \(error)")
        }
    }
    
    public func loadMoreMessages() async {
        guard !isLoadingMore && hasMoreMessages && !isInitialLoad else {
            return
        }
        
        isLoadingMore = true
        
        do {
            let liveChatClient = sdk.getLiveChatClient()
            let fetchedMessages = try await liveChatClient.getEscalationMessages(
                escalationId: escalationId,
                limit: pageSize,
                offset: currentOffset
            )
            
            // Filter out duplicates before inserting
            let existingIds = Set(messages.map { $0.id })
            let newMessages = fetchedMessages.filter { !existingIds.contains($0.id) }
            
            // Insert older messages at the beginning
            let sortedNewMessages = newMessages.sorted { $0.createdAt < $1.createdAt }
            messages.insert(contentsOf: sortedNewMessages, at: 0)
            
            hasMoreMessages = fetchedMessages.count == pageSize
            currentOffset += fetchedMessages.count
            isLoadingMore = false
        } catch {
            isLoadingMore = false
        }
    }
    
    public func sendMessage() async {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        let text = messageText
        messageText = ""
        isSending = true
        
        // Create optimistic message
        let optimisticMessage = ChatMessage(
            id: "temp-\(UUID().uuidString)",
            escalationId: escalationId,
            messageType: "text",
            messageText: text,
            senderType: "agent",
            senderName: "You",
            senderId: nil,
            attachmentUrl: nil,
            attachmentType: nil,
            attachmentName: nil,
            isRead: false,
            readAt: nil,
            createdAt: Date()
        )
        
        // Add optimistic message immediately
        messages.append(optimisticMessage)
        
        // Trigger scroll to new message
        scrollToMessageId = optimisticMessage.id
        
        do {
            let liveChatClient = sdk.getLiveChatClient()
            let sentMessage = try await liveChatClient.sendEscalationMessage(
                escalationId: escalationId,
                text: text
            )
            
            // Replace optimistic message with real one
            if let index = messages.firstIndex(where: { $0.id == optimisticMessage.id }) {
                messages[index] = sentMessage
                // Trigger scroll to real message
                scrollToMessageId = sentMessage.id
            }
            
            // Note: Pusher subscription will also receive this message
            // The duplicate check in connect() will prevent adding it again
            
            isSending = false
        } catch {
            // Remove optimistic message on error
            messages.removeAll { $0.id == optimisticMessage.id }
            
            messageText = text
            isSending = false
        }
    }
    
    public func endChat(reason: String? = nil) async {
        do {
            let liveChatClient = sdk.getLiveChatClient()
            try await liveChatClient.endEscalation(escalationId: escalationId, reason: reason)
            currentStatus = "closed"
            // Return true to indicate success
        } catch {
            // Silently fail
        }
    }
    
    public func acceptChat() async {
        do {
            let liveChatClient = sdk.getLiveChatClient()
            try await liveChatClient.updateEscalationStatus(escalationId: escalationId, status: "active")
            currentStatus = "active"
        } catch {
            // Silently fail
        }
    }
    
    public func resolveChat(notes: String? = nil) async {
        do {
            let liveChatClient = sdk.getLiveChatClient()
            try await liveChatClient.resolveEscalation(escalationId: escalationId, notes: notes)
            currentStatus = "resolved"
            // Return true to indicate success
        } catch {
            // Silently fail
        }
    }
    
    public func closeChat() async {
        do {
            let liveChatClient = sdk.getLiveChatClient()
            try await liveChatClient.updateEscalationStatus(escalationId: escalationId, status: "closed")
            currentStatus = "closed"
        } catch {
            // Silently fail
        }
    }
    
    public func reopenChat() async {
        do {
            let liveChatClient = sdk.getLiveChatClient()
            try await liveChatClient.updateEscalationStatus(escalationId: escalationId, status: "active")
            currentStatus = "active"
        } catch {
            // Silently fail
        }
    }
    
    public func transferChat() {
        // Not implemented
    }
}
