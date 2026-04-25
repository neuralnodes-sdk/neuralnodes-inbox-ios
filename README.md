# NeuralNodes Inbox SDK for iOS

[![Swift Version](https://img.shields.io/badge/Swift-5.5+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/platform-iOS%2013.0+-lightgrey.svg)](https://developer.apple.com/ios/)
[![SPM Compatible](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swift.org/package-manager/)

A powerful, production-ready iOS SDK for integrating NeuralNodes Inbox into your iOS applications. Built with SwiftUI and UIKit support, featuring real-time messaging, live chat, and comprehensive conversation management.

## Features

- Native iOS Experience - Built with SwiftUI and UIKit
- Real-time Messaging - Instant message delivery with Ably and Pusher
- Live Chat Support - Handle customer escalations in real-time
- Conversation Management - Full inbox with filtering and status updates
- Customizable UI - Adapt the interface to match your brand
- Push Notifications - APNs integration for message alerts
- Optimistic Updates - Instant UI feedback for better UX
- Pagination - Efficient message loading with infinite scroll
- Multi-channel Support - WhatsApp, Telegram, Web Chat, and more

## Requirements

- iOS 13.0+
- Xcode 13.0+
- Swift 5.5+

## Installation

### Swift Package Manager (Recommended)

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/neuralnodes-sdk/neuralnodes-inbox-ios.git", from: "1.0.0")
]
```

Or in Xcode:

1. Go to **File > Add Package Dependencies**
2. Enter the repository URL: `https://github.com/neuralnodes-sdk/neuralnodes-inbox-ios.git`
3. Select the version you want to use
4. Click **Add Package**

### CocoaPods

```ruby
pod 'NeuralNodesInbox', '~> 1.0'
```

## Quick Start

### 1. Initialize the SDK

```swift
import NeuralNodesInbox

class AppDelegate: UIResponder, UIApplicationDelegate {
    var sdk: NeuralNodesInbox?
    
    func application(_ application: UIApplication, 
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Initialize SDK
        sdk = NeuralNodesInbox(apiKey: "your_api_key_here")
        
        // Load configuration
        sdk?.initialize { result in
            switch result {
            case .success(let config):
                print("SDK initialized successfully")
            case .failure(let error):
                print("Failed to initialize SDK: \(error)")
            }
        }
        
        return true
    }
}
```

### 2. Show the Inbox (UIKit)

```swift
import NeuralNodesInbox

class ViewController: UIViewController {
    
    @IBAction func showInboxTapped(_ sender: UIButton) {
        guard let sdk = (UIApplication.shared.delegate as? AppDelegate)?.sdk else {
            return
        }
        
        sdk.showInbox(from: self)
    }
}
```

### 3. SwiftUI Integration

```swift
import SwiftUI
import NeuralNodesInbox

struct ContentView: View {
    @StateObject private var appState = AppState()
    
    var body: some View {
        NavigationView {
            VStack {
                Button("Open Inbox") {
                    // Navigate to inbox
                }
            }
        }
        .environmentObject(appState)
        .onAppear {
            appState.initializeSDK(apiKey: "your_api_key_here")
        }
    }
}

@MainActor
class AppState: ObservableObject {
    @Published var sdk: NeuralNodesInbox?
    @Published var isInitialized = false
    
    func initializeSDK(apiKey: String) {
        sdk = NeuralNodesInbox(apiKey: apiKey)
        
        sdk?.initialize { [weak self] result in
            switch result {
            case .success:
                self?.isInitialized = true
            case .failure(let error):
                print("SDK initialization failed: \(error)")
            }
        }
    }
}
```

## Core Features

### Conversation Management

#### Fetch Conversations

```swift
let apiClient = sdk.getAPIClient()

// Fetch all conversations
let conversations = try await apiClient.getConversations()

// Fetch with filters
let filters = ConversationFilters(
    status: "active",
    channel: "whatsapp",
    limit: 50,
    offset: 0
)
let filteredConversations = try await apiClient.getConversations(filters: filters)
```

#### Get Messages

```swift
let messages = try await apiClient.getMessages(
    conversationId: "conversation_id",
    limit: 15,
    offset: 0
)
```

#### Send Messages

```swift
let message = try await apiClient.sendMessage(
    conversationId: "conversation_id",
    text: "Hello, how can I help you?"
)
```

#### Update Conversation Status

```swift
try await apiClient.updateStatus(
    conversationId: "conversation_id",
    status: "resolved"
)
```

#### Mark as Read

```swift
try await apiClient.markAsRead(conversationId: "conversation_id")
```

### Live Chat

#### Get Live Chat Client

```swift
let liveChatClient = sdk.getLiveChatClient()
```

#### Fetch Escalations

```swift
let escalations = try await liveChatClient.getEscalations(
    status: "active",
    limit: 50,
    offset: 0
)
```

#### Get Escalation Messages

```swift
let messages = try await liveChatClient.getEscalationMessages(
    escalationId: "escalation_id",
    limit: 15,
    offset: 0
)
```

#### Send Escalation Message

```swift
let message = try await liveChatClient.sendEscalationMessage(
    escalationId: "escalation_id",
    text: "I'm here to help!"
)
```

#### End Escalation

```swift
try await liveChatClient.endEscalation(escalationId: "escalation_id")
```

### Real-time Updates

#### Subscribe to Conversation Updates (Ably)

```swift
let realtimeClient = sdk.getRealtimeClient()

realtimeClient.subscribeToConversation("conversation_id") { message in
    print("New message received: \(message.messageText)")
}
```

#### Subscribe to Escalation Updates (Pusher)

```swift
let pusherClient = sdk.getPusherClient()

pusherClient.subscribeToEscalation(
    "escalation_id",
    onMessage: { message in
        print("New message: \(message.messageText)")
    },
    onTyping: { isTyping in
        print("User is typing: \(isTyping)")
    }
)
```

#### Unsubscribe

```swift
// Unsubscribe from Ably
realtimeClient.unsubscribe(from: "conversation_id")

// Unsubscribe from Pusher
pusherClient.unsubscribe(from: "escalation_id")
```

### Push Notifications

#### Register for Push Notifications

```swift
import UserNotifications

// Request permission
UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
    if granted {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
}

// Handle device token
func application(_ application: UIApplication, 
                 didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    sdk?.registerForPushNotifications(deviceToken: deviceToken)
}

// Handle incoming notifications
func application(_ application: UIApplication,
                 didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                 fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    
    if let conversationId = sdk?.handlePushNotification(userInfo) {
        // Navigate to conversation
        print("Open conversation: \(conversationId)")
    }
    
    completionHandler(.newData)
}
```

## Customization

### Custom UI Components

You can build your own UI using the SDK's API clients:

```swift
import SwiftUI
import NeuralNodesInbox

struct CustomInboxView: View {
    @StateObject private var viewModel: CustomInboxViewModel
    
    var body: some View {
        List(viewModel.conversations) { conversation in
            NavigationLink(destination: CustomConversationView(conversation: conversation)) {
                ConversationRow(conversation: conversation)
            }
        }
        .task {
            await viewModel.loadConversations()
        }
    }
}

@MainActor
class CustomInboxViewModel: ObservableObject {
    @Published var conversations: [Conversation] = []
    private let apiClient: APIClient
    
    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }
    
    func loadConversations() async {
        do {
            conversations = try await apiClient.getConversations()
        } catch {
            print("Error loading conversations: \(error)")
        }
    }
}
```

### Theming

The SDK respects iOS system appearance (light/dark mode) automatically. You can customize colors by modifying the UI components or using your own views with the API clients.

## Advanced Usage

### Error Handling

```swift
do {
    let messages = try await apiClient.getMessages(
        conversationId: "conversation_id",
        limit: 15,
        offset: 0
    )
} catch APIError.invalidURL {
    print("Invalid URL")
} catch APIError.httpError(let statusCode) {
    print("HTTP error: \(statusCode)")
} catch APIError.decodingError(let error) {
    print("Decoding error: \(error)")
} catch {
    print("Unknown error: \(error)")
}
```

### Pagination

```swift
class MessageViewModel: ObservableObject {
    @Published var messages: [Message] = []
    private var currentOffset = 0
    private let pageSize = 15
    
    func loadMoreMessages(conversationId: String) async {
        do {
            let newMessages = try await apiClient.getMessages(
                conversationId: conversationId,
                limit: pageSize,
                offset: currentOffset
            )
            
            messages.append(contentsOf: newMessages)
            currentOffset += newMessages.count
        } catch {
            print("Error loading more messages: \(error)")
        }
    }
}
```

### Optimistic Updates

```swift
func sendMessage(text: String) async {
    // Create optimistic message
    let optimisticMessage = Message(
        id: "temp-\(UUID().uuidString)",
        conversationId: conversationId,
        messageType: "text",
        messageText: text,
        senderType: "agent",
        senderName: "You",
        senderId: nil,
        attachmentUrl: nil,
        attachmentType: nil,
        attachmentName: nil,
        isRead: false,
        createdAt: Date()
    )
    
    // Add to UI immediately
    messages.append(optimisticMessage)
    
    do {
        // Send to server
        let sentMessage = try await apiClient.sendMessage(
            conversationId: conversationId,
            text: text
        )
        
        // Replace optimistic message with real one
        if let index = messages.firstIndex(where: { $0.id == optimisticMessage.id }) {
            messages[index] = sentMessage
        }
    } catch {
        // Remove optimistic message on error
        messages.removeAll { $0.id == optimisticMessage.id }
    }
}
```

## API Reference

### NeuralNodesInbox

Main SDK class for initialization and configuration.

#### Properties

- `isInitialized: Bool` - Check if SDK is initialized
- `static var version: String` - Get SDK version
- `static var fullVersion: String` - Get full SDK version string

#### Methods

- `init(apiKey: String)` - Initialize SDK with API key
- `initialize(completion: @escaping (Result<SDKConfig, Error>) -> Void)` - Load configuration
- `showInbox(from: UIViewController)` - Show inbox UI (UIKit)
- `registerForPushNotifications(deviceToken: Data)` - Register device for push
- `handlePushNotification(_ userInfo: [AnyHashable: Any]) -> String?` - Handle incoming notification
- `getAPIClient() -> APIClient` - Get API client
- `getLiveChatClient() -> LiveChatClient` - Get live chat client
- `getRealtimeClient() -> RealtimeClient` - Get real-time client (Ably)
- `getPusherClient() -> PusherClient` - Get Pusher client
- `getConfig() -> SDKConfig?` - Get current configuration
- `disconnect()` - Disconnect and cleanup

### APIClient

HTTP client for REST API operations.

#### Methods

- `getConfig() async throws -> SDKConfig`
- `getConversations(filters: ConversationFilters) async throws -> [Conversation]`
- `getConversation(id: String) async throws -> Conversation`
- `getMessages(conversationId: String, limit: Int, offset: Int) async throws -> [Message]`
- `sendMessage(conversationId: String, text: String, attachmentUrl: String?) async throws -> Message`
- `markAsRead(conversationId: String) async throws`
- `updateStatus(conversationId: String, status: String) async throws`
- `registerDevice(token: String, platform: String, deviceInfo: [String: Any]) async throws`

### LiveChatClient

Client for live chat and escalation management.

#### Methods

- `getEscalations(status: String?, limit: Int, offset: Int) async throws -> [Escalation]`
- `getEscalation(id: String) async throws -> Escalation`
- `getEscalationMessages(escalationId: String, limit: Int, offset: Int) async throws -> [ChatMessage]`
- `sendEscalationMessage(escalationId: String, text: String) async throws -> ChatMessage`
- `endEscalation(escalationId: String) async throws`

### RealtimeClient

Real-time messaging client using Ably.

#### Methods

- `connect(with: String)` - Connect with Ably key
- `subscribeToConversation(_ conversationId: String, onMessage: @escaping (Message) -> Void)`
- `unsubscribe(from: String)`
- `disconnect()`

### PusherClient

Real-time client for live chat using Pusher.

#### Methods

- `connect(key: String, cluster: String)` - Connect to Pusher
- `subscribeToEscalation(_ escalationId: String, onMessage: @escaping (ChatMessage) -> Void, onTyping: @escaping (Bool) -> Void)`
- `unsubscribe(from: String)`
- `disconnect()`

## Troubleshooting

### SDK Not Initializing

Make sure you're calling `initialize()` and waiting for the completion handler before using other SDK features.

### Messages Not Appearing

Check that:
1. Real-time clients are connected
2. You're subscribed to the correct conversation/escalation ID
3. API key has proper permissions

### Push Notifications Not Working

Verify:
1. Push notification capabilities are enabled in Xcode
2. APNs certificate is configured correctly
3. Device token is registered with `registerForPushNotifications()`

## License

Copyright (c) 2024 NeuralNodes. All rights reserved.

This SDK is proprietary software. You may use this SDK only in accordance with the terms of your agreement with NeuralNodes. Unauthorized copying, modification, distribution, or use of this SDK is strictly prohibited.

For licensing inquiries, contact: support@neuralnodes.space

## Support

- Email: support@neuralnodes.space
- Documentation: https://docs.neuralnodes.space
- Issues: https://github.com/neuralnodes-sdk/neuralnodes-inbox-ios/issues

---

Made by [NeuralNodes](https://neuralnodes.space)
