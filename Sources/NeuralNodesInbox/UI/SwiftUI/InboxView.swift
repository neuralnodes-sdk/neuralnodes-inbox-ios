import SwiftUI

/// SwiftUI wrapper for InboxViewController
@available(iOS 14.0, *)
public struct InboxView: UIViewControllerRepresentable {
    
    let apiClient: APIClient
    let realtimeClient: RealtimeClient
    let config: SDKConfig
    
    public init(apiClient: APIClient, realtimeClient: RealtimeClient, config: SDKConfig) {
        self.apiClient = apiClient
        self.realtimeClient = realtimeClient
        self.config = config
    }
    
    public func makeUIViewController(context: Context) -> UINavigationController {
        let inboxVC = InboxViewController(
            apiClient: apiClient,
            realtimeClient: realtimeClient,
            config: config
        )
        return UINavigationController(rootViewController: inboxVC)
    }
    
    public func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        // No updates needed
    }
}

/// SwiftUI modifier to present inbox
@available(iOS 14.0, *)
public extension View {
    func neuralNodesInbox(
        isPresented: Binding<Bool>,
        apiClient: APIClient,
        realtimeClient: RealtimeClient,
        config: SDKConfig
    ) -> some View {
        self.fullScreenCover(isPresented: isPresented) {
            InboxView(
                apiClient: apiClient,
                realtimeClient: realtimeClient,
                config: config
            )
            .ignoresSafeArea()
        }
    }
}
