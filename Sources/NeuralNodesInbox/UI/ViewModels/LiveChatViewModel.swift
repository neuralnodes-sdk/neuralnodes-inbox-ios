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
    
    public let escalationId: String
    private let sdk: NeuralNodesInbox
    private let pageSize = 15
    private var currentOffset = 0
    private var isInitialLoad = true
    
    public init(escalationId: String, sdk: NeuralNodesInbox) {
        self.escalationId = escalationId
        self.sdk = sdk
    }
    
    public func connect() async {
        do {
            try await Task.sleep(nanoseconds: 500_000_000)
            isConnected = true
            
            // Subscribe to Pusher channel
            let pusherClient = sdk.getPusherClient()
            pusherClient.subscribeToEscalation(escalationId, onMessage: { [weak self] message in
                Task { @MainActor in
                    guard let self = self else { return }
                    
                    // Avoid duplicates - check if message already exists
                    guard !self.messages.contains(where: { $0.id == message.id }) else {
                        return
                    }
                    
                    self.messages.append(message)
                    self.scrollToMessageId = message.id
                }
            }, onTyping: { [weak self] isTyping in
                Task { @MainActor in
                    self?.isTyping = isTyping
                }
            })
        } catch {
            isConnected = false
        }
    }
    
    public func disconnect() {
        let pusherClient = sdk.getPusherClient()
        pusherClient.unsubscribe(from: escalationId)
        isConnected = false
    }
    
    public func loadMessages() async {
        currentOffset = 0
        hasMoreMessages = true
        isInitialLoad = true
        
        do {
            let liveChatClient = sdk.getLiveChatClient()
            let fetchedMessages = try await liveChatClient.getEscalationMessages(
                escalationId: escalationId,
                limit: pageSize,
                offset: currentOffset
            )
            
            messages = fetchedMessages.sorted { $0.createdAt < $1.createdAt }
            hasMoreMessages = fetchedMessages.count == pageSize
            currentOffset = pageSize
            
            // Scroll to bottom after messages loaded
            if let lastMessage = messages.last {
                scrollToMessageId = lastMessage.id
            }
            
            // Mark as no longer initial load after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.isInitialLoad = false
            }
        } catch {
            // Silently fail
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
    
    public func endChat() {
        Task {
            do {
                let liveChatClient = sdk.getLiveChatClient()
                try await liveChatClient.endEscalation(escalationId: escalationId)
            } catch {
                // Silently fail
            }
        }
    }
    
    public func transferChat() {
        // Not implemented
    }
}
