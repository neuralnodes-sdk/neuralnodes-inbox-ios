import SwiftUI

/// Main tab view for the Inbox SDK
/// This is a CONVENIENCE wrapper - developers can also use individual views
public struct InboxTabView: View {
    private let sdk: NeuralNodesInbox
    @State private var selectedTab = 0
    
    public init(sdk: NeuralNodesInbox) {
        self.sdk = sdk
    }
    
    public var body: some View {
        TabView(selection: $selectedTab) {
            // Unified Inbox Tab
            InboxView(sdk: sdk)
                .tabItem {
                    Label("Inbox", systemImage: "tray.2.fill")
                }
                .tag(0)
            
            // Live Chat Tab
            LiveChatListView(sdk: sdk)
                .tabItem {
                    Label("Live Chat", systemImage: "message.fill")
                }
                .tag(1)
            
            // Settings Tab
            InboxSettingsView(sdk: sdk)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(2)
        }
        .accentColor(.primaryPurple)
    }
}
