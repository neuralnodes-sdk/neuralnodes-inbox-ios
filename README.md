# NeuralNodes Inbox SDK for iOS

A powerful, flexible iOS SDK for integrating customer support inbox functionality into your app. Choose from plug-and-play UI components or build completely custom interfaces with our headless API.

## Features

- **Multi-channel Support** - WhatsApp, Email, SMS, Web Chat
- **Real-time Messaging** - Instant message delivery with Ably and Pusher
- **Live Chat Escalations** - Handle escalated conversations
- **Push Notifications** - APNs integration for message alerts
- **Status Management** - Active, Pending, Resolved, Closed workflows
- **Message Pagination** - Efficient loading of conversation history
- **Optimistic Updates** - Instant UI feedback
- **Flexible Integration** - Use pre-built UI or build your own

## Requirements

- iOS 16.0+
- Swift 5.7+
- Xcode 14.0+

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/neuralnodes-sdk/neuralnodes-inbox-ios.git", from: "1.0.0")
]
```

Or in Xcode:
1. File → Add Package Dependencies
2. Enter: `https://github.com/neuralnodes-sdk/neuralnodes-inbox-ios.git`
3. Select version and add to your target

## Quick Start

### 1. Initialize the SDK

```swift
import NeuralNodesInbox

let sdk = NeuralNodesInbox(apiKey: "your-api-key")

sdk.initialize { result in
    switch result {
    case .success(let config):
        print("SDK initialized successfully")
    case .failure(let error):
        print("Initialization failed: \(error)")
    }
}
```

### 2. Choose Your Integration Level

The SDK offers three integration approaches, from easiest to most customizable:

---

## Integration Options

### Option 1: Plug & Play (Fastest) ⚡

**Best for:** Quick integration, standard UI requirements

Get a complete inbox interface with just one line of code:

```swift
import SwiftUI
import NeuralNodesInbox

struct ContentView: View {
    let sdk: NeuralNodesInbox
    
    var body: some View {
        NavigationStack {
            InboxTabView(sdk: sdk)
        }
    }
}
```

**What you get:**
- Complete tab bar with Inbox, Live Chat, and Settings
- All features working out of the box
- Professional, tested UI
- Zero UI code required

**Time to integrate:** 5 minutes

---

### Option 2: Component Integration (Flexible) 🎨

**Best for:** Custom app structure, branded experience

Use individual SDK views within your own navigation:

```swift
import SwiftUI
import NeuralNodesInbox

struct MyApp: View {
    let sdk: NeuralNodesInbox
    
    var body: some View {
        TabView {
            // Your existing tabs
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }
            
            // Add SDK inbox view
            NavigationStack {
                InboxView(sdk: sdk)
            }
            .tabItem { Label("Support", systemImage: "message") }
            
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person") }
        }
    }
}
```

#### Available Views

```swift
// Main Views
InboxView(sdk: sdk)                          // Conversation list with filters
ConversationDetailView(conversation, sdk)     // Chat interface
LiveChatListView(sdk: sdk)                   // Escalation list
LiveChatView(escalation, sdk)                // Live chat interface
InboxSettingsView(sdk: sdk)                  // SDK information

// Convenience Wrapper
InboxTabView(sdk: sdk)                       // Complete tab bar UI
```

#### Example: Modal Presentation

```swift
Button("Open Support") {
    showSupport = true
}
.sheet(isPresented: $showSupport) {
    NavigationStack {
        InboxView(sdk: sdk)
    }
}
```

#### Example: Embedded in Settings

```swift
NavigationStack {
    List {
        Section("Account") {
            // Your settings
        }
        
        Section("Support") {
            NavigationLink("Messages") {
                InboxView(sdk: sdk)
            }
            NavigationLink("Live Chat") {
                LiveChatListView(sdk: sdk)
            }
        }
    }
}
```

**Time to integrate:** 30 minutes

---

### Option 3: Headless API (Full Control) 🔧

**Best for:** Completely custom UI, unique design requirements

Build your own interface using SDK data and APIs:

#### Get API Clients

```swift
let apiClient = sdk.getAPIClient()
let liveChatClient = sdk.getLiveChatClient()
let realtimeClient = sdk.getRealtimeClient()
let pusherClient = sdk.getPusherClient()
```

#### Fetch Conversations

```swift
// Get conversations with filters
let conversations = try await apiClient.getConversations(
    filters: ConversationFilters(
        status: "active",
        channel: "whatsapp",
        limit: 20,
        offset: 0
    )
)

// Get specific conversation
let conversation = try await apiClient.getConversation(id: conversationId)

// Get messages
let messages = try await apiClient.getConversationMessages(
    conversationId: conversationId,
    limit: 50,
    offset: 0
)
```

#### Send Messages

```swift
let message = try await apiClient.sendMessage(
    conversationId: conversationId,
    text: "Hello, how can I help?"
)
```

#### Update Status

```swift
try await apiClient.updateConversationStatus(
    conversationId: conversationId,
    status: "resolved"
)

try await apiClient.markAsRead(conversationId: conversationId)
```

#### Real-time Updates

```swift
// Subscribe to conversation updates
realtimeClient.subscribeToConversation(conversationId) { message in
    // Update your UI with new message
    print("New message: \(message.messageText)")
}

// Unsubscribe when done
realtimeClient.unsubscribe(from: conversationId)
```

#### Live Chat

```swift
// Get escalations
let escalations = try await liveChatClient.getEscalations(limit: 50)

// Get escalation messages
let messages = try await liveChatClient.getEscalationMessages(
    escalationId: escalationId,
    limit: 50,
    offset: 0
)

// Send message
let message = try await liveChatClient.sendEscalationMessage(
    escalationId: escalationId,
    text: "Message text"
)

// Subscribe to live chat updates
pusherClient.subscribeToEscalation(
    escalationId,
    onMessage: { message in
        // Handle new message
    },
    onTyping: { isTyping in
        // Handle typing indicator
    }
)
```

#### Example: Custom ViewModel

```swift
import NeuralNodesInbox

@MainActor
class CustomInboxViewModel: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var isLoading = false
    
    private let sdk: NeuralNodesInbox
    
    init(sdk: NeuralNodesInbox) {
        self.sdk = sdk
    }
    
    func loadConversations() async {
        isLoading = true
        
        do {
            let apiClient = sdk.getAPIClient()
            conversations = try await apiClient.getConversations()
            isLoading = false
        } catch {
            print("Error: \(error)")
            isLoading = false
        }
    }
    
    func sendMessage(to conversationId: String, text: String) async {
        do {
            let apiClient = sdk.getAPIClient()
            let message = try await apiClient.sendMessage(
                conversationId: conversationId,
                text: text
            )
            // Update your UI
        } catch {
            print("Error: \(error)")
        }
    }
}
```

**Time to integrate:** 2-4 hours

---

## Push Notifications

### 1. Request Permission

```swift
import UserNotifications

UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
    if granted {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
}
```

### 2. Register Device Token

```swift
func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    sdk.registerForPushNotifications(deviceToken: deviceToken)
}
```

### 3. Handle Notifications

```swift
func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) {
    let conversationId = sdk.handlePushNotification(response.notification.request.content.userInfo)
    // Navigate to conversation if needed
}
```

---

## API Reference

### Core SDK

```swift
// Initialize
let sdk = NeuralNodesInbox(apiKey: String)
sdk.initialize(completion: (Result<SDKConfig, Error>) -> Void)

// Properties
sdk.isInitialized: Bool
NeuralNodesInbox.version: String

// Get Clients
sdk.getAPIClient() -> APIClient
sdk.getLiveChatClient() -> LiveChatClient
sdk.getRealtimeClient() -> RealtimeClient
sdk.getPusherClient() -> PusherClient

// Push Notifications
sdk.registerForPushNotifications(deviceToken: Data)
sdk.handlePushNotification([AnyHashable: Any]) -> String?

// Cleanup
sdk.disconnect()
```

### APIClient

```swift
// Configuration
getConfig() async throws -> SDKConfig

// Conversations
getConversations(filters: ConversationFilters) async throws -> [Conversation]
getConversation(id: String) async throws -> Conversation
getConversationMessages(conversationId: String, limit: Int, offset: Int) async throws -> [Message]
sendMessage(conversationId: String, text: String) async throws -> Message
updateConversationStatus(conversationId: String, status: String) async throws
markAsRead(conversationId: String) async throws
```

### LiveChatClient

```swift
getEscalations(limit: Int) async throws -> [Escalation]
getEscalationMessages(escalationId: String, limit: Int, offset: Int) async throws -> [ChatMessage]
sendEscalationMessage(escalationId: String, text: String) async throws -> ChatMessage
endEscalation(escalationId: String) async throws
```

### RealtimeClient

```swift
subscribeToConversation(_ conversationId: String, onMessage: @escaping (Message) -> Void)
unsubscribe(from conversationId: String)
```

### PusherClient

```swift
subscribeToEscalation(_ escalationId: String, onMessage: @escaping (ChatMessage) -> Void, onTyping: @escaping (Bool) -> Void)
unsubscribe(from escalationId: String)
```

---

## Models

### Conversation

```swift
public struct Conversation: Identifiable, Codable {
    public let id: String
    public let channel: String
    public let status: String
    public let customerName: String?
    public let customerPhone: String?
    public let customerEmail: String?
    public let lastMessagePreview: String?
    public let lastMessageAt: Date?
    public let unreadCount: Int
    public let createdAt: Date
    public let updatedAt: Date
}
```

### Message

```swift
public struct Message: Identifiable, Codable {
    public let id: String
    public let conversationId: String
    public let messageType: String
    public let messageText: String
    public let senderType: String
    public let senderName: String?
    public let senderId: String?
    public let isRead: Bool
    public let readAt: Date?
    public let createdAt: Date
}
```

### Escalation

```swift
public struct Escalation: Identifiable, Codable {
    public let id: String
    public let conversationId: String
    public let status: String
    public let reason: String?
    public let customerName: String?
    public let lastMessageAt: Date?
    public let createdAt: Date
}
```

### ChatMessage

```swift
public struct ChatMessage: Identifiable, Codable {
    public let id: String
    public let escalationId: String
    public let messageType: String
    public let messageText: String
    public let senderType: String
    public let senderName: String?
    public let createdAt: Date
}
```

---

## Comparison Table

| Feature | Plug & Play | Component | Headless API |
|---------|-------------|-----------|--------------|
| **Setup Time** | 5 minutes | 30 minutes | 2-4 hours |
| **UI Control** | Low | Medium | Full |
| **Customization** | Theme only | Layout & Navigation | Everything |
| **Code Required** | 1 line | 10-50 lines | 100+ lines |
| **Best For** | Quick setup | Branded apps | Unique designs |
| **Maintenance** | SDK handles | Shared | You handle |

---

## Best Practices

### 1. Initialize Early

Initialize the SDK in your app's startup sequence:

```swift
@main
struct MyApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}

class AppState: ObservableObject {
    @Published var sdk: NeuralNodesInbox?
    
    init() {
        let sdk = NeuralNodesInbox(apiKey: "your-api-key")
        sdk.initialize { result in
            if case .success = result {
                self.sdk = sdk
            }
        }
    }
}
```

### 2. Handle Errors Gracefully

```swift
do {
    let conversations = try await apiClient.getConversations()
} catch {
    // Show user-friendly error message
    showError("Unable to load conversations. Please try again.")
}
```

### 3. Cleanup on Logout

```swift
func logout() {
    sdk.disconnect()
    // Clear user data
}
```

### 4. Use Real-time Subscriptions Wisely

```swift
// Subscribe when view appears
.onAppear {
    realtimeClient.subscribeToConversation(conversationId) { message in
        // Handle message
    }
}

// Unsubscribe when view disappears
.onDisappear {
    realtimeClient.unsubscribe(from: conversationId)
}
```

---

## Support

- **Documentation:** [https://github.com/neuralnodes-sdk/neuralnodes-inbox-ios/blob/main/README.md](https://github.com/neuralnodes-sdk/neuralnodes-inbox-ios/blob/main/README.md)
- **Email:** support@neuralnodes.com
- **Issues:** [GitHub Issues](https://github.com/neuralnodes-sdk/neuralnodes-inbox-ios/issues)

---

## License

Copyright © 2024 NeuralNodes. All rights reserved.

This SDK is proprietary software. Unauthorized copying, distribution, or modification is prohibited.

---
