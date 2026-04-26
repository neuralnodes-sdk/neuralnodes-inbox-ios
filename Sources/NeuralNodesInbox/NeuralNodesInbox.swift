import UIKit
import Ably

public class NeuralNodesInbox {
    
    private let apiKey: String
    private let apiClient: APIClient
    private let liveChatClient: LiveChatClient
    private let realtimeClient: RealtimeClient
    private let pusherClient: PusherClient
    private let pushService: PushNotificationService
    private let searchService: SearchService
    private var config: SDKConfig?
    
    public init(apiKey: String) {
        self.apiKey = apiKey
        self.apiClient = APIClient(apiKey: apiKey)
        self.liveChatClient = LiveChatClient(apiClient: self.apiClient)
        self.realtimeClient = RealtimeClient()
        self.pusherClient = PusherClient()
        self.pushService = PushNotificationService(apiClient: apiClient)
        self.searchService = SearchService(apiClient: apiClient, debounceInterval: 0.3)
    }
    
    public func initialize(completion: @escaping (Result<SDKConfig, Error>) -> Void) {
        Task {
            do {
                let config = try await apiClient.getConfig()
                
                // Check if SDK is enabled
                guard config.enabled else {
                    let error = NSError(
                        domain: "com.neuralnodes.sdk",
                        code: 403,
                        userInfo: [
                            NSLocalizedDescriptionKey: "Mobile SDK is not enabled for this account. Please contact support to enable it."
                        ]
                    )
                    await MainActor.run {
                        completion(.failure(error))
                    }
                    return
                }
                
                self.config = config
                
                if let ablyKey = config.ablyKey {
                    realtimeClient.connect(with: ablyKey)
                }
                if let pusherKey = config.pusherKey, let pusherCluster = config.pusherCluster {
                    pusherClient.connect(key: pusherKey, cluster: pusherCluster)
                }
                
                await MainActor.run {
                    completion(.success(config))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
    
    public func showInbox(from viewController: UIViewController) {
        guard config != nil else {
            return
        }
        
        let inboxVC = InboxViewController(
            apiClient: apiClient,
            realtimeClient: realtimeClient,
            config: config!
        )
        let navController = UINavigationController(rootViewController: inboxVC)
        navController.modalPresentationStyle = .fullScreen
        viewController.present(navController, animated: true)
    }
    
    public func registerForPushNotifications(deviceToken: Data) {
        Task {
            do {
                try await pushService.registerDevice(token: deviceToken)
            } catch {
                // Handle error silently
            }
        }
    }
    
    @discardableResult
    public func handlePushNotification(_ userInfo: [AnyHashable: Any]) -> String? {
        return pushService.handleNotification(userInfo)
    }
    
    public func getAPIClient() -> APIClient {
        return apiClient
    }
    
    public func getLiveChatClient() -> LiveChatClient {
        return liveChatClient
    }
    
    public func getRealtimeClient() -> RealtimeClient {
        return realtimeClient
    }
    
    public func getPusherClient() -> PusherClient {
        return pusherClient
    }
    
    public func getSearchService() -> SearchService {
        return searchService
    }
    
    public func getConfig() -> SDKConfig? {
        return config
    }
    
    public var isInitialized: Bool {
        return config != nil
    }
    
    public static var version: String {
        return SDKVersion.version
    }
    
    public static var fullVersion: String {
        return SDKVersion.fullVersion
    }
    
    public func disconnect() {
        realtimeClient.disconnect()
        pusherClient.disconnect()
    }
    
    deinit {
        disconnect()
    }
}
