import SwiftUI
import Combine

@MainActor
public class LiveChatListViewModel: ObservableObject {
    @Published public var escalations: [Escalation] = []
    @Published public var isLoading = false
    
    private let sdk: NeuralNodesInbox
    
    public init(sdk: NeuralNodesInbox) {
        self.sdk = sdk
    }
    
    public func loadEscalations(status: String? = nil) async {
        isLoading = true
        
        do {
            let liveChatClient = sdk.getLiveChatClient()
            // TODO: Update LiveChatClient to support status filtering
            escalations = try await liveChatClient.getEscalations(limit: 50)
            
            // Filter by status on client side for now
            if let status = status {
                escalations = escalations.filter { $0.status.lowercased() == status.lowercased() }
            }
            
            isLoading = false
        } catch {
            isLoading = false
        }
    }
    
    public func searchEscalations(query: String, status: String? = nil) async {
        guard !query.isEmpty else {
            await loadEscalations(status: status)
            return
        }
        
        isLoading = true
        
        do {
            let searchService = sdk.getSearchService()
            let filters = ConversationSearchFilters(
                query: query,
                channel: nil,
                status: status,
                liveChat: true,  // Filter for live chat only
                limit: 50,
                offset: 0
            )
            
            let response = try await searchService.searchConversationsImmediate(filters: filters)
            
            // Convert search results to escalations
            // Note: This is a simplified conversion. You may need to adjust based on your data model
            escalations = response.results.compactMap { result in
                // Only include if it's a live chat escalation
                // You might need additional logic here based on your backend
                return nil // Placeholder - needs proper conversion
            }
            
            isLoading = false
        } catch {
            isLoading = false
        }
    }
}
