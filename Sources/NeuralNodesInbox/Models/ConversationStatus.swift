import SwiftUI

/// Conversation status types
public enum ConversationStatus: String, CaseIterable, Identifiable {
    case all = "all"
    case active = "active"
    case pending = "pending"
    case resolved = "resolved"
    case closed = "closed"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .all: return "All Status"
        case .active: return "Active"
        case .pending: return "Pending"
        case .resolved: return "Resolved"
        case .closed: return "Closed"
        }
    }
    
    public var icon: String {
        switch self {
        case .all: return "circle.grid.3x3.fill"
        case .active: return "circle.fill"
        case .pending: return "clock.fill"
        case .resolved: return "checkmark.circle.fill"
        case .closed: return "xmark.circle.fill"
        }
    }
    
    public var color: Color {
        switch self {
        case .all: return .primary
        case .active: return .successGreen
        case .pending: return .warningYellow
        case .resolved: return .gray
        case .closed: return .errorRed
        }
    }
}
