import Foundation
import os.log

/// Professional logging system for SDK
public class NeuralNodesLogger {
    
    public enum LogLevel: Int {
        case debug = 0
        case info = 1
        case warning = 2
        case error = 3
        case none = 4
    }
    
    public static var logLevel: LogLevel = .info
    
    private static let subsystem = "com.neuralnodes.inbox"
    
    private static let networkLog = OSLog(subsystem: subsystem, category: "Network")
    private static let realtimeLog = OSLog(subsystem: subsystem, category: "Realtime")
    private static let uiLog = OSLog(subsystem: subsystem, category: "UI")
    private static let generalLog = OSLog(subsystem: subsystem, category: "General")
    
    // MARK: - Network Logging
    
    public static func logNetworkRequest(_ method: String, path: String) {
        guard logLevel.rawValue <= LogLevel.debug.rawValue else { return }
        os_log("🌐 %{public}@ %{public}@", log: networkLog, type: .debug, method, path)
    }
    
    public static func logNetworkResponse(_ statusCode: Int, path: String) {
        guard logLevel.rawValue <= LogLevel.debug.rawValue else { return }
        os_log("✅ %{public}d %{public}@", log: networkLog, type: .debug, statusCode, path)
    }
    
    public static func logNetworkError(_ error: Error, path: String) {
        guard logLevel.rawValue <= LogLevel.error.rawValue else { return }
        os_log("❌ Network error on %{public}@: %{public}@", log: networkLog, type: .error, path, error.localizedDescription)
    }
    
    // MARK: - Realtime Logging
    
    public static func logRealtimeConnected(_ service: String) {
        guard logLevel.rawValue <= LogLevel.info.rawValue else { return }
        os_log("✅ %{public}@ connected", log: realtimeLog, type: .info, service)
    }
    
    public static func logRealtimeDisconnected(_ service: String) {
        guard logLevel.rawValue <= LogLevel.warning.rawValue else { return }
        os_log("⚠️ %{public}@ disconnected", log: realtimeLog, type: .default, service)
    }
    
    public static func logRealtimeMessage(_ channel: String) {
        guard logLevel.rawValue <= LogLevel.debug.rawValue else { return }
        os_log("📨 Message received on %{public}@", log: realtimeLog, type: .debug, channel)
    }
    
    // MARK: - UI Logging
    
    public static func logViewPresented(_ viewName: String) {
        guard logLevel.rawValue <= LogLevel.debug.rawValue else { return }
        os_log("📱 %{public}@ presented", log: uiLog, type: .debug, viewName)
    }
    
    public static func logUserAction(_ action: String) {
        guard logLevel.rawValue <= LogLevel.debug.rawValue else { return }
        os_log("👆 User action: %{public}@", log: uiLog, type: .debug, action)
    }
    
    // MARK: - General Logging
    
    public static func info(_ message: String) {
        guard logLevel.rawValue <= LogLevel.info.rawValue else { return }
        os_log("ℹ️ %{public}@", log: generalLog, type: .info, message)
    }
    
    public static func warning(_ message: String) {
        guard logLevel.rawValue <= LogLevel.warning.rawValue else { return }
        os_log("⚠️ %{public}@", log: generalLog, type: .default, message)
    }
    
    public static func error(_ message: String) {
        guard logLevel.rawValue <= LogLevel.error.rawValue else { return }
        os_log("❌ %{public}@", log: generalLog, type: .error, message)
    }
    
    public static func debug(_ message: String) {
        guard logLevel.rawValue <= LogLevel.debug.rawValue else { return }
        os_log("🔍 %{public}@", log: generalLog, type: .debug, message)
    }
}
