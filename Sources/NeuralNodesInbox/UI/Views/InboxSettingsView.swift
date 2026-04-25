import SwiftUI

/// Settings view for the Inbox SDK
public struct InboxSettingsView: View {
    private let sdk: NeuralNodesInbox
    @Environment(\.colorScheme) var colorScheme
    
    public init(sdk: NeuralNodesInbox) {
        self.sdk = sdk
    }
    
    private var sdkVersion: String {
        SDKVersion.version
    }
    
    private var sdkBuild: String {
        SDKVersion.buildNumber ?? "N/A"
    }
    
    public var body: some View {
        List {
            Section(header: Text("SDK Information")) {
                HStack {
                    Text("Version")
                        .foregroundColor(.primary)
                    Spacer()
                    Text(sdkVersion)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Build")
                        .foregroundColor(.primary)
                    Spacer()
                    Text(sdkBuild)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Platform")
                        .foregroundColor(.primary)
                    Spacer()
                    Text("iOS")
                        .foregroundColor(.secondary)
                }
            }
            
            Section(header: Text("About")) {
                HStack {
                    Text("Powered by")
                        .foregroundColor(.primary)
                    Spacer()
                    Text("NeuralNodes Inbox SDK")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.visible, for: .tabBar)
    }
}
