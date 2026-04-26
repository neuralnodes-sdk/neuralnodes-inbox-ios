import SwiftUI
import Combine

@MainActor
public class LiveChatListViewModel: ObservableObject {
    @Published public var escalations: [Escalation] = []
    @Published public var isLoading = false
    
    private let sdk: NeuralNodesInbox
    private var hasSubscribed = false
    private var refreshTask: Task<Void, Never>?
    private var isRefreshing = false // Prevent concurrent API calls
    
    public init(sdk: NeuralNodesInbox) {
        self.sdk = sdk
    }
    
    private func setupRealtimeSubscription() {
        // Only subscribe once
        guard !hasSubscribed else {
            print("ℹ️ [LIVE CHAT LIST] Already subscribed to real-time updates")
            return
        }
        
        print("🔌 [LIVE CHAT LIST] Setting up real-time subscription")
        
        let pusherClient = sdk.getPusherClient()
        let apiClient = sdk.getAPIClient()
        
        // Get clientId from API client
        guard let clientId = apiClient.getClientId() else {
            print("⚠️ [LIVE CHAT LIST] Cannot subscribe - clientId not available")
            return
        }
        
        print("👤 [LIVE CHAT LIST] Client ID: \(clientId)")
        
        pusherClient.subscribeToEscalationList(clientId: clientId) { [weak self] in
            print("🔔 [LIVE CHAT LIST] Pusher callback triggered - scheduling refresh")
            Task { @MainActor in
                await self?.loadEscalationsWithDebounce()
            }
        }
        
        hasSubscribed = true
        print("✅ [LIVE CHAT LIST] Real-time subscription setup complete")
    }
    
    /// Load escalations with debounce to prevent rapid successive calls
    private func loadEscalationsWithDebounce() async {
        print("🔄 [LIVE CHAT LIST] loadEscalationsWithDebounce called")
        
        // Cancel any pending refresh
        refreshTask?.cancel()
        
        // Schedule new refresh with 500ms delay
        refreshTask = Task {
            print("⏳ [LIVE CHAT LIST] Waiting 500ms before refresh...")
            do {
                try await Task.sleep(nanoseconds: 500_000_000) // 500ms
                guard !Task.isCancelled else {
                    print("❌ [LIVE CHAT LIST] Refresh task was cancelled")
                    return
                }
                print("✅ [LIVE CHAT LIST] Executing refresh now")
                await loadEscalations()
            } catch {
                // Task was cancelled or sleep failed
                print("❌ [LIVE CHAT LIST] Refresh task error: \(error)")
            }
        }
    }
    
    public func loadEscalations(status: String? = nil) async {
        print("📥 [LIVE CHAT LIST] loadEscalations started")
        
        // Prevent concurrent API calls
        guard !isRefreshing else {
            print("⚠️ [LIVE CHAT LIST] Already refreshing, skipping this call")
            return
        }
        
        isRefreshing = true
        isLoading = true
        
        do {
            let liveChatClient = sdk.getLiveChatClient()
            print("🌐 [LIVE CHAT LIST] Fetching escalations from API...")
            escalations = try await liveChatClient.getEscalations(limit: 50)
            
            print("✅ [LIVE CHAT LIST] Received \(escalations.count) escalations")
            
            isLoading = false
            isRefreshing = false
            
            // Setup real-time subscription after first successful load
            setupRealtimeSubscription()
        } catch {
            print("❌ [LIVE CHAT LIST] Error loading escalations: \(error)")
            isLoading = false
            isRefreshing = false
        }
    }
}
