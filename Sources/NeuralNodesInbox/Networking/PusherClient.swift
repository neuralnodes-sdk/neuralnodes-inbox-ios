import Foundation
import PusherSwift

/// Real-time client using Pusher for live chat escalations
public class PusherClient {
    
    private var pusher: Pusher?
    private var subscribedChannels: [String: PusherChannel] = [:]
    
    public init() {}
    
    // MARK: - Connection
    
    public func connect(key: String, cluster: String) {
        let options = PusherClientOptions(
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
        subscribedChannels.keys.forEach { channelName in
            pusher?.unsubscribe("escalation-\(channelName)")
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
        guard let pusher = pusher else {
            print("⚠️ Pusher not initialized")
            return
        }
        
        let channelName = "escalation-\(escalationId)"
        let channel = pusher.subscribe(channelName)
        
        // Subscribe to new messages
        let _ = channel.bind(eventName: "new-message") { (event: PusherEvent) in
            guard let data = event.data,
                  let jsonData = data.data(using: .utf8) else {
                print("⚠️ Failed to get message data")
                return
            }
            
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
                print("⚠️ Failed to decode chat message")
                return
            }
            
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
        print("✅ Subscribed to escalation: \(escalationId)")
    }
    
    public func unsubscribe(from escalationId: String) {
        guard subscribedChannels[escalationId] != nil else { return }
        let channelName = "escalation-\(escalationId)"
        pusher?.unsubscribe(channelName)
        subscribedChannels.removeValue(forKey: escalationId)
        print("✅ Unsubscribed from escalation: \(escalationId)")
    }
    
    public func subscribeToEscalationList(onUpdate: @escaping () -> Void) {
        guard pusher != nil else {
            print("⚠️ Pusher not initialized")
            return
        }
        
        let channel = pusher?.subscribe("escalations")
        let _ = channel?.bind(eventName: "update") { _ in
            onUpdate()
        }
        
        print("✅ Subscribed to escalation list updates")
    }
    
    // MARK: - Trigger Events
    
    public func sendTypingIndicator(escalationId: String, isTyping: Bool) {
        guard let pusher = pusher,
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
