import Foundation
import UIKit

/// Service for handling push notifications
public class PushNotificationService {
    
    private let apiClient: APIClient
    private let deviceIdKey = "com.neuralnodes.deviceId"
    
    public init(apiClient: APIClient) {
        self.apiClient = apiClient
    }
    
    // MARK: - Device ID Management
    
    /// Get a persistent device identifier
    private func getDeviceId() -> String {
        #if targetEnvironment(simulator)
        // For simulator, use a persistent UUID stored in UserDefaults
        if let existingId = UserDefaults.standard.string(forKey: deviceIdKey) {
            return existingId
        } else {
            let newId = "simulator-\(UUID().uuidString)"
            UserDefaults.standard.set(newId, forKey: deviceIdKey)
            return newId
        }
        #else
        // For real devices, use identifierForVendor (persists across app installs)
        if let vendorId = UIDevice.current.identifierForVendor?.uuidString {
            return vendorId
        } else {
            // Fallback: generate and store a UUID
            if let existingId = UserDefaults.standard.string(forKey: deviceIdKey) {
                return existingId
            } else {
                let newId = UUID().uuidString
                UserDefaults.standard.set(newId, forKey: deviceIdKey)
                return newId
            }
        }
        #endif
    }
    
    // MARK: - Device Registration
    
    public func registerDevice(token: Data) async throws {
        let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()
        let deviceId = getDeviceId()
        
        let deviceInfo: [String: Any] = [
            "model": UIDevice.current.model,
            "system_version": UIDevice.current.systemVersion,
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            "is_simulator": isSimulator()
        ]
        
        try await apiClient.registerDevice(
            token: tokenString,
            platform: "ios",
            deviceId: deviceId,
            deviceInfo: deviceInfo
        )
    }

    
    // Helper function to check if running on simulator
    private func isSimulator() -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
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
