import SwiftUI
import Combine

@MainActor
public class ConversationDetailViewModel: ObservableObject {
    @Published public var messages: [Message] = []
    @Published public var messageText: String = ""
    @Published public var isLoading = false
    @Published public var isSending = false
    @Published public var showError = false
    @Published public var errorMessage: String?
    @Published public var isLoadingMore = false
    @Published public var hasMoreMessages = true
    @Published public var scrollToMessageId: String?
    
    public let conversationId: String
    public let conversationStatus: String
    private let sdk: NeuralNodesInbox
    private let pageSize = 15
    private var currentOffset = 0
    private var isInitialLoad = true
    
    public init(conversationId: String, conversationStatus: String, sdk: NeuralNodesInbox) {
        self.conversationId = conversationId
        self.conversationStatus = conversationStatus
        self.sdk = sdk
    }
    
    public func startListening() {
        let realtimeClient = sdk.getRealtimeClient()
        realtimeClient.subscribeToConversation(conversationId) { [weak self] message in
            guard let self = self else { return }
            
            Task { @MainActor in
                // Check if message already exists (avoid duplicates)
                guard !self.messages.contains(where: { $0.id == message.id }) else {
                    return
                }
                
                self.messages.append(message)
                self.scrollToMessageId = message.id
            }
        }
    }
    
    public func stopListening() {
        let realtimeClient = sdk.getRealtimeClient()
        realtimeClient.unsubscribe(from: conversationId)
    }
    
    public func loadMessages() async {
        isLoading = true
        currentOffset = 0
        hasMoreMessages = true
        isInitialLoad = true
        
        do {
            let apiClient = sdk.getAPIClient()
            let fetchedMessages = try await apiClient.getMessages(
                conversationId: conversationId,
                limit: pageSize,
                offset: currentOffset
            )
            
            messages = fetchedMessages.sorted { $0.createdAt < $1.createdAt }
            hasMoreMessages = fetchedMessages.count == pageSize
            currentOffset = pageSize
            isLoading = false
            
            if let lastMessage = messages.last {
                scrollToMessageId = lastMessage.id
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.isInitialLoad = false
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            isLoading = false
        }
    }
    
    public func loadMoreMessages() async {
        guard !isLoadingMore && hasMoreMessages && !isInitialLoad else {
            return
        }
        
        isLoadingMore = true
        
        do {
            let apiClient = sdk.getAPIClient()
            let fetchedMessages = try await apiClient.getMessages(
                conversationId: conversationId,
                limit: pageSize,
                offset: currentOffset
            )
            
            let existingIds = Set(messages.map { $0.id })
            let newMessages = fetchedMessages.filter { !existingIds.contains($0.id) }
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
        
        let optimisticMessage = Message(
            id: "temp-\(UUID().uuidString)",
            conversationId: conversationId,
            messageType: "text",
            messageText: text,
            senderType: "agent",
            senderName: "You",
            senderId: nil,
            attachmentUrl: nil,
            attachmentType: nil,
            attachmentName: nil,
            isRead: false,
            createdAt: Date()
        )
        
        messages.append(optimisticMessage)
        scrollToMessageId = optimisticMessage.id
        
        do {
            let apiClient = sdk.getAPIClient()
            let sentMessage = try await apiClient.sendMessage(
                conversationId: conversationId,
                text: text
            )
            
            if let index = messages.firstIndex(where: { $0.id == optimisticMessage.id }) {
                messages[index] = sentMessage
                scrollToMessageId = sentMessage.id
            }
            
            // Auto-change status from pending to active
            if conversationStatus == "pending" {
                try await apiClient.updateStatus(conversationId: conversationId, status: "active")
            }
            
            isSending = false
        } catch {
            messages.removeAll { $0.id == optimisticMessage.id }
            messageText = text
            errorMessage = error.localizedDescription
            showError = true
            isSending = false
        }
    }
    
    public func markAsRead() {
        Task {
            do {
                let apiClient = sdk.getAPIClient()
                try await apiClient.markAsRead(conversationId: conversationId)
            } catch {
                // Silently fail
            }
        }
    }
    
    public func updateStatus(to status: String) async {
        do {
            let apiClient = sdk.getAPIClient()
            try await apiClient.updateStatus(conversationId: conversationId, status: status)
            
            await MainActor.run {
                NotificationCenter.default.post(name: NSNotification.Name("RefreshInboxAndDismiss"), object: nil)
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
