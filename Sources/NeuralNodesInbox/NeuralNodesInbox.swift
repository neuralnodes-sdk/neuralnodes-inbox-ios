import UIKit
import SwiftUI
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
                    pusherClient.connect(key: pusherKey, cluster: pusherCluster, apiKey: apiKey)
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
    
    /// Logs in as a specific agent instead of every escalation action
    /// being attributed to this client's shared API key. Purely additive
    /// - skip this and Live Chat keeps working exactly as before.
    @discardableResult
    public func login(email: String, password: String) async throws -> AgentUser {
        return try await apiClient.login(email: email, password: password)
    }

    public func logoutAgent() async {
        await apiClient.logout()
    }

    /// The currently logged-in agent, or nil if login() was never called
    /// (the default - every action then runs as the shared client API
    /// key).
    public var currentAgent: AgentUser? {
        return apiClient.currentAgent
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
    
    /// Returns the appropriate color scheme based on dark mode setting
    /// - Returns: nil if dark mode is enabled (respects system), .light if disabled
    public func getColorScheme() -> ColorScheme? {
        guard let config = config else { return nil }
        
        // Check if dark mode feature is enabled
        guard config.features.darkMode else {
            return .light 
        }
        
        // Check user preference from AppStorage
        let forceDarkMode = UserDefaults.standard.bool(forKey: "forceDarkMode")
        if forceDarkMode {
            return .dark // Force dark mode if user enabled it
        }
        
        // Otherwise respect system setting
        return nil
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
