import Foundation

/// SDK Version Information
public struct SDKVersion {
    public static let version = "2.0.0"
    
    public static let name = "NeuralNodesInbox-iOS"
    
    public static let fullVersion = "\(name)/\(version)"
    
    public static var userAgent: String {
        let systemVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let platform = "iOS"
        return "\(name)/\(version) (\(platform); \(systemVersion))"
    }
    
    public static var buildNumber: String?
    
    public static var versionWithBuild: String {
        if let build = buildNumber {
            return "\(version)+\(build)"
        }
        return version
    }
}
