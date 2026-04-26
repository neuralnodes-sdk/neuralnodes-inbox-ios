import SwiftUI

public struct LiveChatListView: View {
    @StateObject private var viewModel: LiveChatListViewModel
    @State private var searchText = ""
    @State private var selectedStatus: EscalationStatus = .all
    
    private let sdk: NeuralNodesInbox
    
    private var isSearchEnabled: Bool {
        sdk.getConfig()?.features.conversationSearch ?? false
    }
    
    public init(sdk: NeuralNodesInbox) {
        self.sdk = sdk
        _viewModel = StateObject(wrappedValue: LiveChatListViewModel(sdk: sdk))
    }
    
    // Status filter enum
    enum EscalationStatus: String, CaseIterable {
        case all = "all"
        case pending = "pending"
        case active = "active"
        case resolved = "resolved"
        case closed = "closed"
        
        var displayName: String {
            switch self {
            case .all: return "All"
            case .pending: return "Pending"
            case .active: return "Active"
            case .resolved: return "Resolved"
            case .closed: return "Closed"
            }
        }
        
        var icon: String {
            switch self {
            case .all: return "tray.2.fill"
            case .pending: return "clock.fill"
            case .active: return "circle.fill"
            case .resolved: return "checkmark.circle.fill"
            case .closed: return "xmark.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .all: return .secondary
            case .pending: return .warningYellow
            case .active: return .successGreen
            case .resolved: return .primaryPurple
            case .closed: return .secondary
            }
        }
    }
    
    private var filteredEscalations: [Escalation] {
        let statusFiltered: [Escalation]
        if selectedStatus == .all {
            statusFiltered = viewModel.escalations
        } else {
            statusFiltered = viewModel.escalations.filter { $0.status.lowercased() == selectedStatus.rawValue }
        }
        
        if searchText.isEmpty {
            return statusFiltered
        }
        
        return statusFiltered.filter { escalation in
            escalation.displayName.localizedCaseInsensitiveContains(searchText) ||
            escalation.leadEmail?.localizedCaseInsensitiveContains(searchText) == true ||
            escalation.lastMessagePreview?.localizedCaseInsensitiveContains(searchText) == true
        }
    }
    
    private func statusCount(for status: EscalationStatus) -> Int {
        guard status != .all else { return viewModel.escalations.count }
        return viewModel.escalations.filter { $0.status.lowercased() == status.rawValue }.count
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Search Bar - only show if conversation search is enabled
            if isSearchEnabled {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search live chats", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .autocapitalization(.none)
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                Divider()
            }
            
            // Status Filter Chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(EscalationStatus.allCases, id: \.self) { status in
                        StatusChip(
                            status: status,
                            count: statusCount(for: status),
                            isSelected: selectedStatus == status,
                            onTap: {
                                selectedStatus = status
                            }
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
            }
            .background(Color(.systemBackground))
            
            Divider()
            
            // Content
            if viewModel.isLoading && viewModel.escalations.isEmpty {
                LoadingView()
            } else if filteredEscalations.isEmpty {
                EmptyStateView(
                    icon: "message.badge",
                    title: searchText.isEmpty ? "No Live Chats" : "No Results",
                    message: searchText.isEmpty ? "Active escalations will appear here" : "Try adjusting your search or filters"
                )
            } else {
                List {
                    ForEach(filteredEscalations) { escalation in
                        NavigationLink(destination: LiveChatView(escalation: escalation, sdk: sdk)) {
                            LiveChatRow(escalation: escalation)
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .navigationTitle("Live Chat")
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.visible, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { 
                    Task { 
                        await viewModel.loadEscalations()
                    } 
                }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.loadEscalations()
            }
        }
    }
}

// MARK: - Status Chip Component

struct StatusChip: View {
    let status: LiveChatListView.EscalationStatus
    let count: Int
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: status.icon)
                    .font(.system(size: 10))
                
                Text(status.displayName)
                    .font(.system(size: 12, weight: .medium))
                
                Text("(\(count))")
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? status.color : Color(.systemGray6))
            .foregroundColor(isSelected ? .white : status.color)
            .cornerRadius(16)
        }
    }
}
