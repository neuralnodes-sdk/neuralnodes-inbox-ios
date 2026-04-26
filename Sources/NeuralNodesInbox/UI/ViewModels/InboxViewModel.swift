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
        guard !hasSubscribed else { return }
        
        let realtimeClient = sdk.getRealtimeClient()
        let apiClient = sdk.getAPIClient()
        
        // Get clientId from API client
        guard let clientId = apiClient.getClientId() else {
            return
        }
        
        realtimeClient.subscribeToInbox(clientId: clientId) { [weak self] in
            Task { @MainActor in
                await self?.loadConversations()
            }
        }
        
        hasSubscribed = true
    }
    
    public func loadConversations() async {
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
            
            let fetchedConversations = try await apiClient.getConversations(filters: filters)
            
            conversations = fetchedConversations
            isLoading = false
            
            // Setup real-time subscription after first successful load
            setupRealtimeSubscription()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            isLoading = false
            conversations = []
        }
    }
}
