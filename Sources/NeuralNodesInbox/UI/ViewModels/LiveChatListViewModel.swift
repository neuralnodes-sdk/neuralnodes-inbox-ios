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
    
    public func loadEscalations() async {
        isLoading = true
        
        do {
            let liveChatClient = sdk.getLiveChatClient()
            escalations = try await liveChatClient.getEscalations(limit: 50)
            isLoading = false
        } catch {
            isLoading = false
        }
    }
}
