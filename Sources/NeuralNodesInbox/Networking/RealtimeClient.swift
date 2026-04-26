import Foundation
import Ably

/// Real-time client using Ably for live updates
public class RealtimeClient {
    
    private var ably: ARTRealtime?
    private var subscribedChannels: [String: ARTRealtimeChannel] = [:]
    
    public init() {}
    
    // MARK: - Connection
    
    public func connect(with key: String) {
        let options = ARTClientOptions(key: key)
        options.autoConnect = true
        ably = ARTRealtime(options: options)
        
        ably?.connection.on { stateChange in
            let state = stateChange.current
            switch state {
            case .connected:
                NeuralNodesLogger.logRealtimeConnected("Ably")
            case .disconnected:
                NeuralNodesLogger.logRealtimeDisconnected("Ably")
            case .failed:
                NeuralNodesLogger.error("Ably connection failed")
            default:
                break
            }
        }
    }
    
    public func disconnect() {
        subscribedChannels.values.forEach { $0.unsubscribe() }
        subscribedChannels.removeAll()
        ably?.close()
        ably = nil
    }
    
    // MARK: - Subscriptions
    
    public func subscribeToConversation(_ conversationId: String, onMessage: @escaping (Message) -> Void) {
        guard let ably = ably else {
            print("⚠️ Ably not connected")
            return
        }
        
        let channelName = "conversation-\(conversationId)"
        let channel = ably.channels.get(channelName)
        
        channel.subscribe("new-message") { message in
            guard let data = message.data as? [String: Any],
                  let jsonData = try? JSONSerialization.data(withJSONObject: data) else {
                NeuralNodesLogger.warning("Failed to get Ably message data")
                return
            }
            
            // Use custom decoder with date handling
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                
                // Try ISO8601DateFormatter first (handles fractional seconds and timezones)
                if #available(iOS 11.0, *) {
                    let iso8601Formatter = ISO8601DateFormatter()
                    
                    // Try with fractional seconds and timezone
                    iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    if let date = iso8601Formatter.date(from: dateString) {
                        return date
                    }
                    
                    // Try without fractional seconds but with timezone
                    iso8601Formatter.formatOptions = [.withInternetDateTime]
                    if let date = iso8601Formatter.date(from: dateString) {
                        return date
                    }
                    
                    // Try with fractional seconds but without timezone
                    iso8601Formatter.formatOptions = [.withFullDate, .withFullTime, .withFractionalSeconds, .withDashSeparatorInDate, .withColonSeparatorInTime]
                    if let date = iso8601Formatter.date(from: dateString) {
                        return date
                    }
                }
                
                // Fallback to DateFormatter for custom formats
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                
                let formats = [
                    "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ",  // With microseconds and timezone
                    "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",       // With microseconds, no timezone
                    "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ",     // With milliseconds and timezone
                    "yyyy-MM-dd'T'HH:mm:ss.SSS",          // With milliseconds, no timezone
                    "yyyy-MM-dd'T'HH:mm:ssZZZZZ",         // No fractional seconds, with timezone
                    "yyyy-MM-dd'T'HH:mm:ss"               // No fractional seconds, no timezone
                ]
                
                for format in formats {
                    formatter.dateFormat = format
                    if let date = formatter.date(from: dateString) {
                        return date
                    }
                }
                
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string: \(dateString)")
            }
            
            guard let decodedMessage = try? decoder.decode(Message.self, from: jsonData) else {
                NeuralNodesLogger.warning("Failed to decode Ably message")
                return
            }
            
            NeuralNodesLogger.logRealtimeMessage(channelName)
            onMessage(decodedMessage)
        }
        
        subscribedChannels[conversationId] = channel
        NeuralNodesLogger.info("Subscribed to conversation: \(conversationId)")
    }
    
    public func unsubscribe(from conversationId: String) {
        guard let channel = subscribedChannels[conversationId] else { return }
        channel.unsubscribe()
        subscribedChannels.removeValue(forKey: conversationId)
        NeuralNodesLogger.info("Unsubscribed from conversation: \(conversationId)")
    }
    
    public func subscribeToInbox(clientId: String, onUpdate: @escaping () -> Void) {
        guard let ably = ably else {
            return
        }
        
        // Subscribe to client-specific inbox updates channel
        let channelName = "inbox-updates-\(clientId)"
        let channel = ably.channels.get(channelName)
        
        // Subscribe to all events on the inbox-updates channel
        channel.subscribe { message in
            onUpdate()
        }
        
        subscribedChannels["inbox-updates"] = channel
    }
}
