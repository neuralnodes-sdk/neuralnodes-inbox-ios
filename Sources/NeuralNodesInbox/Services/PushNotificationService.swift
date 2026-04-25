import Foundation
import UIKit

/// Service for handling push notifications
public class PushNotificationService {
    
    private let apiClient: APIClient
    
    public init(apiClient: APIClient) {
        self.apiClient = apiClient
    }
    
    // MARK: - Device Registration
    
    public func registerDevice(token: Data) async throws {
        let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()
        
        let deviceInfo: [String: Any] = [
            "model": UIDevice.current.model,
            "system_version": UIDevice.current.systemVersion,
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        ]
        
        try await apiClient.registerDevice(
            token: tokenString,
            platform: "ios",
            deviceInfo: deviceInfo
        )
    }
    
    // MARK: - Notification Handling
    
    public func handleNotification(_ userInfo: [AnyHashable: Any]) -> String? {
        // Extract conversation ID from notification payload
        if let conversationId = userInfo["conversation_id"] as? String {
            return conversationId
        }
        
        if let aps = userInfo["aps"] as? [String: Any],
           let conversationId = aps["conversation_id"] as? String {
            return conversationId
        }
        
        return nil
    }
}
