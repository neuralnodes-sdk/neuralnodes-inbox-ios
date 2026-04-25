import SwiftUI
import NeuralNodesInbox

@main
struct ExampleApp: App {
    @StateObject private var inboxManager = InboxManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(inboxManager)
        }
    }
}

class InboxManager: ObservableObject {
    let inbox: NeuralNodesInbox
    @Published var isInitialized = false
    @Published var config: SDKConfig?
    
    init() {
        // Replace with your actual API key
        self.inbox = NeuralNodesInbox(apiKey: "your-client-api-key-here")
        initialize()
    }
    
    func initialize() {
        inbox.initialize { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let config):
                    self.config = config
                    self.isInitialized = true
                    print("✅ SDK initialized successfully")
                case .failure(let error):
                    print("❌ SDK initialization failed: \\(error)")
                }
            }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var inboxManager: InboxManager
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if inboxManager.isInitialized {
                    Text("✅ SDK Ready")
                        .font(.title2)
                        .foregroundColor(.green)
                    
                    Button(action: openInbox) {
                        Label("Open Inbox", systemImage: "tray.fill")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    if let config = inboxManager.config {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Configuration")
                                .font(.headline)
                            Text("Features:")
                            Text("• Push Notifications: \\(config.features.pushNotifications ? "✅" : "❌")")
                            Text("• File Upload: \\(config.features.fileUpload ? "✅" : "❌")")
                            Text("• Real-time: \\(config.ablyKey != nil ? "✅" : "❌")")
                        }
                        .font(.caption)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }
                } else {
                    ProgressView("Initializing SDK...")
                }
            }
            .navigationTitle("NeuralNodes Inbox")
        }
    }
    
    func openInbox() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }
        inboxManager.inbox.showInbox(from: rootViewController)
    }
}
