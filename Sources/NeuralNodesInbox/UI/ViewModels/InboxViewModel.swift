import SwiftUI
import Combine

@MainActor
public class InboxViewModel: ObservableObject {
    @Published public var conversations: [Conversation] = []
    @Published public var selectedChannel: Channel = .all
    @Published public var selectedStatus: ConversationStatus = .active
    @Published public var isLoading = false
    @Published public var showError = false
    @Published public var errorMessage: String?
    
    private let sdk: NeuralNodesInbox
    private var cancellables = Set<AnyCancellable>()
    private var hasSubscribed = false
    private var refreshTask: Task<Void, Never>?
    private var isRefreshing = false // Prevent concurrent API calls
    
    public var isSubscribed: Bool {
        return hasSubscribed
    }
    
    public init(sdk: NeuralNodesInbox) {
        self.sdk = sdk
        
        // Watch for filter changes
        Publishers.CombineLatest($selectedChannel, $selectedStatus)
            .dropFirst()
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _, _ in
                Task {
                    await self?.loadConversations()
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupRealtimeSubscription() {
        // Only subscribe once
        guard !hasSubscribed else {
            print("ℹ️ [INBOX] Already subscribed to real-time updates")
            return
        }
        
        print("🔌 [INBOX] Setting up real-time subscription")
        
        let realtimeClient = sdk.getRealtimeClient()
        let apiClient = sdk.getAPIClient()
        
        // Get clientId from API client
        guard let clientId = apiClient.getClientId() else {
            print("⚠️ [INBOX] Cannot subscribe - clientId not available")
            return
        }
        
        print("👤 [INBOX] Client ID: \(clientId)")
        
        realtimeClient.subscribeToInbox(clientId: clientId) { [weak self] in
            print("🔔 [INBOX] Ably callback triggered - scheduling refresh")
            Task { @MainActor in
                await self?.loadConversationsWithDebounce()
            }
        }
        
        hasSubscribed = true
        print("✅ [INBOX] Real-time subscription setup complete")
    }
    
    /// Load conversations with debounce to prevent rapid successive calls
    public func loadConversationsWithDebounce() async {
        print("🔄 [INBOX] loadConversationsWithDebounce called")
        
        // Cancel any pending refresh
        refreshTask?.cancel()
        
        // Schedule new refresh with 500ms delay (increased to give backend time to update)
        refreshTask = Task {
            print("⏳ [INBOX] Waiting 500ms before refresh...")
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
            guard !Task.isCancelled else {
                print("❌ [INBOX] Refresh task was cancelled")
                return
            }
            print("✅ [INBOX] Executing refresh now")
            await loadConversations()
        }
    }
    
    public func loadConversations() async {
        print("📥 [INBOX] loadConversations started")
        
        // Prevent concurrent API calls
        guard !isRefreshing else {
            print("⚠️ [INBOX] Already refreshing, skipping this call")
            return
        }
        
        isRefreshing = true
        isLoading = true
        errorMessage = nil
        showError = false
        
        do {
            let apiClient = sdk.getAPIClient()
            let channel = selectedChannel == .all ? nil : selectedChannel.rawValue
            let status = selectedStatus == .all ? nil : selectedStatus.rawValue
            
            let filters = ConversationFilters(
                channel: channel,
                status: status,
                assignedTo: nil,
                limit: 50,
                offset: 0
            )
            
            print("🌐 [INBOX] Fetching conversations from API...")
            let fetchedConversations = try await apiClient.getConversations(filters: filters)
            
            print("✅ [INBOX] Received \(fetchedConversations.count) conversations")
            
            // Log unread counts for debugging
            let unreadConversations = fetchedConversations.filter { $0.unreadCount > 0 }
            if !unreadConversations.isEmpty {
                print("📬 [INBOX] Conversations with unread messages:")
                for conv in unreadConversations {
                    print("   - \(conv.contactName ?? "Unknown"): \(conv.unreadCount) unread")
                }
            }
            
            conversations = fetchedConversations
            isLoading = false
            isRefreshing = false
            
            // Setup real-time subscription after first successful load
            setupRealtimeSubscription()
        } catch {
            print("❌ [INBOX] Error loading conversations: \(error)")
            errorMessage = error.localizedDescription
            showError = true
            isLoading = false
            isRefreshing = false
            conversations = []
        }
    }
    
    /// Pause real-time updates (call when navigating to conversation detail)
    public func pauseRealtimeUpdates() {
        print("⏸️ [INBOX] Pausing real-time updates")
        guard hasSubscribed else { return }
        
        let realtimeClient = sdk.getRealtimeClient()
        realtimeClient.unsubscribeFromInbox()
        hasSubscribed = false
    }
    
    /// Resume real-time updates (call when returning to inbox list)
    public func resumeRealtimeUpdates() {
        print("▶️ [INBOX] Resuming real-time updates")
        setupRealtimeSubscription()
    }
}
