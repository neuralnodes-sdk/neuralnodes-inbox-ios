import SwiftUI

/// Settings view for the Inbox SDK
public struct InboxSettingsView: View {
    private let sdk: NeuralNodesInbox
    @Environment(\.colorScheme) var colorScheme
    @State private var showDarkModeAlert = false
    @State private var showRestartAlert = false
    @AppStorage("forceDarkMode") private var forceDarkMode = false
    
    public init(sdk: NeuralNodesInbox) {
        self.sdk = sdk
    }
    
    private var sdkVersion: String {
        SDKVersion.version
    }
    
    private var sdkBuild: String {
        SDKVersion.buildNumber ?? "N/A"
    }
    
    private var isDarkModeEnabled: Bool {
        sdk.getConfig()?.features.darkMode ?? false
    }
    
    private var isInLightMode: Bool {
        colorScheme == .light
    }
    
    public var body: some View {
        List {
            // Dark Mode Section - only show if feature is enabled
            if isDarkModeEnabled {
                Section(header: Text("Appearance")) {
                    // Dark mode toggle
                    Toggle(isOn: $forceDarkMode) {
                        HStack(spacing: 12) {
                            Image(systemName: forceDarkMode ? "moon.fill" : "sun.max.fill")
                                .foregroundColor(forceDarkMode ? .blue : .orange)
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Dark Mode")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text(forceDarkMode ? "Enabled" : "Disabled")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .onChange(of: forceDarkMode) { newValue in
                        showRestartAlert = true
                    }
                    
                    // Show prompt to enable in system settings if disabled and in light mode
                    if !forceDarkMode && isInLightMode {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.blue)
                                Text("You can also enable dark mode in iOS Settings")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Button(action: {
                                showDarkModeAlert = true
                            }) {
                                HStack {
                                    Image(systemName: "gearshape.fill")
                                    Text("Open iOS Settings")
                                        .fontWeight(.medium)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            
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
                
                if isDarkModeEnabled {
                    HStack {
                        Text("Current Appearance")
                            .foregroundColor(.primary)
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: colorScheme == .dark ? "moon.fill" : "sun.max.fill")
                                .font(.caption)
                            Text(colorScheme == .dark ? "Dark" : "Light")
                        }
                        .foregroundColor(.secondary)
                    }
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
        .alert("Enable Dark Mode in iOS", isPresented: $showDarkModeAlert) {
            Button("Open Settings") {
                openSystemSettings()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("To enable dark mode:\n1. Go to Settings > Developer\n2. Under APPEARANCE, toggle 'Dark Appearance' ON")
        }
        .alert("Restart Required", isPresented: $showRestartAlert) {
            Button("Restart Now") {
                restartApp()
            }
            Button("Later", role: .cancel) {}
        } message: {
            Text("The app needs to restart for the appearance change to take effect.")
        }
    }
    
    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    private func restartApp() {
        // Post notification to restart the app
        NotificationCenter.default.post(name: NSNotification.Name("RestartApp"), object: nil)
        
        // Force exit (iOS will restart when user reopens)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            exit(0)
        }
    }
}
