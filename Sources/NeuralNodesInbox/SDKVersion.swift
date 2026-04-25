import Foundation

/// SDK Version Information
public struct SDKVersion {
    public static let version = "2.0.6"
    
    public static let name = "NeuralNodesInbox-iOS"
    
    public static let fullVersion = "\(name)/\(version)"
    
    public static var userAgent: String {
        let systemVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let platform = "iOS"
        return "\(name)/\(version) (\(platform); \(systemVersion))"
    }
    
    // Build number set by CI/CD or defaults to "dev" for local builds
    public static var buildNumber: String? = "12-ba7e981"
    
    public static var versionWithBuild: String {
        if let build = buildNumber {
            return "\(version)+\(build)"
        }
        return version
    }
}
