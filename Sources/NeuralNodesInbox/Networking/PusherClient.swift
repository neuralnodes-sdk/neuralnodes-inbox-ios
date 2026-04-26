import Foundation
import PusherSwift

/// Auth request builder for Pusher private channels
class PusherAuthRequestBuilder: AuthRequestBuilderProtocol {
    private let apiKey: String
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func requestFor(socketID: String, channelName: String) -> URLRequest? {
        guard let url = URL(string: "https://api.neuralnodes.space/pusher/auth") else {
            print("❌ [PUSHER AUTH] Invalid auth URL")
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        
        let bodyString = "socket_id=\(socketID)&channel_name=\(channelName)"
        request.httpBody = bodyString.data(using: .utf8)
        
        print("📡 [PUSHER AUTH] Requesting auth for channel: \(channelName)")
        print("   Socket ID: \(socketID)")
        
        return request
    }
}

/// Real-time client using Pusher for live chat escalations
public class PusherClient {
    
    private var pusher: Pusher?
    private var subscribedChannels: [String: PusherChannel] = [:]
    private var apiKey: String?
    
    public init() {}
    
    // MARK: - Connection
    
    public func connect(key: String, cluster: String, apiKey: String) {
        self.apiKey = apiKey
        
        let options = PusherClientOptions(
            authMethod: .authRequestBuilder(authRequestBuilder: PusherAuthRequestBuilder(apiKey: apiKey)),
            host: .cluster(cluster)
        )
        
        pusher = Pusher(
            key: key,
            options: options
        )
        
        pusher?.connection.delegate = self
        pusher?.connect()
    }
    
    public func disconnect() {
        subscribedChannels.keys.forEach { escalationId in
            pusher?.unsubscribe("private-escalation-\(escalationId)")
        }
        subscribedChannels.removeAll()
        pusher?.disconnect()
        pusher = nil
    }
    
    // MARK: - Connection State
    
    public var isConnected: Bool {
        return pusher?.connection.connectionState == .connected
    }
    
    // MARK: - Subscriptions
    
    public func subscribeToEscalation(
        _ escalationId: String,
        onMessage: @escaping (ChatMessage) -> Void,
        onTyping: @escaping (Bool) -> Void
    ) {
        guard pusher != nil else {
            return
        }
        
        // Backend sends to "private-escalation-{id}" channel
        let channelName = "private-escalation-\(escalationId)"
        print("📡 [PUSHER] Subscribing to channel: \(channelName)")
        let channel = pusher!.subscribe(channelName)
        
        // Subscribe to new messages
        let _ = channel.bind(eventName: "new-message") { (event: PusherEvent) in
            print("📨 [PUSHER] Received new-message event on \(channelName)")
            print("   Event data: \(event.data ?? "nil")")
            
            guard let data = event.data,
                  let jsonData = data.data(using: .utf8) else {
                print("⚠️ [PUSHER] Failed to get message data")
                return
            }
            
            print("📦 [PUSHER] Parsing message JSON...")
            
            // Use custom decoder with date handling
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                
                // Try ISO8601DateFormatter first
                if #available(iOS 11.0, *) {
                    let iso8601Formatter = ISO8601DateFormatter()
                    iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    if let date = iso8601Formatter.date(from: dateString) {
                        return date
                    }
                    iso8601Formatter.formatOptions = [.withInternetDateTime]
                    if let date = iso8601Formatter.date(from: dateString) {
                        return date
                    }
                }
                
                // Fallback to DateFormatter
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ"
                if let date = formatter.date(from: dateString) {
                    return date
                }
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
                if let date = formatter.date(from: dateString) {
                    return date
                }
                
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateString)")
            }
            
            guard let message = try? decoder.decode(ChatMessage.self, from: jsonData) else {
                print("❌ [PUSHER] Failed to decode message")
                return
            }
            
            print("✅ [PUSHER] Message decoded successfully: \(message.messageText)")
            print("🔔 [PUSHER] Calling onMessage callback...")
            onMessage(message)
        }
        
        // Subscribe to typing indicators
        let _ = channel.bind(eventName: "typing") { (event: PusherEvent) in
            guard let data = event.data,
                  let jsonData = data.data(using: .utf8),
                  let typingData = try? JSONDecoder().decode([String: Bool].self, from: jsonData),
                  let isTyping = typingData["is_typing"] else {
                return
            }
            
            onTyping(isTyping)
        }
        
        subscribedChannels[escalationId] = channel
    }
    
    public func unsubscribe(from escalationId: String) {
        guard subscribedChannels[escalationId] != nil else { return }
        let channelName = "private-escalation-\(escalationId)"
        print("🔕 [PUSHER] Unsubscribing from channel: \(channelName)")
        pusher?.unsubscribe(channelName)
        subscribedChannels.removeValue(forKey: escalationId)
    }
    
    public func subscribeToEscalationList(clientId: String, onUpdate: @escaping () -> Void) {
        guard pusher != nil else {
            return
        }
        
        // Check if already subscribed
        if subscribedChannels["escalation-list"] != nil {
            print("ℹ️ [PUSHER] Already subscribed to escalation list, skipping")
            return
        }
        
        // Subscribe to client-specific escalation updates channel
        let channelName = "private-client-\(clientId)"
        print("📡 [PUSHER] Subscribing to escalation list channel: \(channelName)")
        let channel = pusher?.subscribe(channelName)
        
        let _ = channel?.bind(eventName: "new-escalation") { _ in
            print("🔔 [PUSHER] Received new-escalation event")
            onUpdate()
        }
        
        let _ = channel?.bind(eventName: "escalation-update") { _ in
            print("🔔 [PUSHER] Received escalation-update event")
            onUpdate()
        }
        
        subscribedChannels["escalation-list"] = channel
        print("✅ [PUSHER] Subscribed to escalation list updates: \(channelName)")
    }
    
    // MARK: - Trigger Events
    
    public func sendTypingIndicator(escalationId: String, isTyping: Bool) {
        guard pusher != nil,
              let channel = subscribedChannels[escalationId] else {
            return
        }
        
        let data = ["is_typing": isTyping]
        channel.trigger(eventName: "client-typing", data: data)
    }
}

// MARK: - PusherDelegate

extension PusherClient: PusherDelegate {
    public func changedConnectionState(from old: ConnectionState, to new: ConnectionState) {
        switch new {
        case .connected:
            NeuralNodesLogger.logRealtimeConnected("Pusher")
        case .disconnected:
            NeuralNodesLogger.logRealtimeDisconnected("Pusher")
        case .connecting:
            NeuralNodesLogger.debug("Pusher connecting...")
        case .reconnecting:
            NeuralNodesLogger.debug("Pusher reconnecting...")
        default:
            NeuralNodesLogger.debug("Pusher connection state: \(new)")
        }
    }
    
    public func debugLog(message: String) {
        NeuralNodesLogger.debug("Pusher: \(message)")
    }
    
    public func subscribedToChannel(name: String) {
        NeuralNodesLogger.info("Subscribed to Pusher channel: \(name)")
    }
    
    public func failedToSubscribeToChannel(name: String, response: URLResponse?, data: String?, error: NSError?) {
        NeuralNodesLogger.error("Failed to subscribe to Pusher channel: \(name)")
        if let error = error {
            NeuralNodesLogger.error("Error: \(error.localizedDescription)")
        }
    }
}
