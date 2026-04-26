import SwiftUI

public struct LiveChatListView: View {
    @StateObject private var viewModel: LiveChatListViewModel
    @State private var searchText = ""
    @State private var selectedStatus: String? = nil
    @State private var showFilterSheet = false
    
    private let sdk: NeuralNodesInbox
    
    public init(sdk: NeuralNodesInbox) {
        self.sdk = sdk
        _viewModel = StateObject(wrappedValue: LiveChatListViewModel(sdk: sdk))
    }
    
    private let statusOptions = ["active", "closed", "resolved"]
    
    public var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search live chats", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .autocapitalization(.none)
                        .onChange(of: searchText) { newValue in
                            Task {
                                await viewModel.searchEscalations(query: newValue, status: selectedStatus)
                            }
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            Task {
                                await viewModel.loadEscalations(status: selectedStatus)
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                
                // Filter Button
                Button(action: { showFilterSheet = true }) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 20))
                            .foregroundColor(.primaryPurple)
                        
                        if selectedStatus != nil {
                            Circle()
                                .fill(Color.errorRed)
                                .frame(width: 8, height: 8)
                                .offset(x: 2, y: -2)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            
            Divider()
            
            // Content
            if viewModel.isLoading && viewModel.escalations.isEmpty {
                LoadingView()
            } else if viewModel.escalations.isEmpty {
                EmptyStateView(
                    icon: "message.badge",
                    title: searchText.isEmpty ? "No Live Chats" : "No Results",
                    message: searchText.isEmpty ? "Active escalations will appear here" : "Try adjusting your search or filters"
                )
            } else {
                List {
                    ForEach(viewModel.escalations) { escalation in
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
                        if searchText.isEmpty {
                            await viewModel.loadEscalations(status: selectedStatus)
                        } else {
                            await viewModel.searchEscalations(query: searchText, status: selectedStatus)
                        }
                    } 
                }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .sheet(isPresented: $showFilterSheet) {
            LiveChatFilterSheet(
                selectedStatus: $selectedStatus,
                onApply: {
                    showFilterSheet = false
                    Task {
                        if searchText.isEmpty {
                            await viewModel.loadEscalations(status: selectedStatus)
                        } else {
                            await viewModel.searchEscalations(query: searchText, status: selectedStatus)
                        }
                    }
                },
                onClear: {
                    selectedStatus = nil
                    showFilterSheet = false
                    Task {
                        if searchText.isEmpty {
                            await viewModel.loadEscalations(status: nil)
                        } else {
                            await viewModel.searchEscalations(query: searchText, status: nil)
                        }
                    }
                }
            )
        }
        .onAppear {
            Task {
                await viewModel.loadEscalations(status: selectedStatus)
            }
        }
    }
}

// MARK: - Live Chat Filter Sheet

struct LiveChatFilterSheet: View {
    @Binding var selectedStatus: String?
    let onApply: () -> Void
    let onClear: () -> Void
    
    private let statusOptions = [
        ("active", "Active", "circle.fill", Color.successGreen),
        ("closed", "Closed", "xmark.circle.fill", Color.secondary),
        ("resolved", "Resolved", "checkmark.circle.fill", Color.primaryPurple)
    ]
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Status")) {
                    ForEach(statusOptions, id: \.0) { status in
                        Button(action: {
                            selectedStatus = status.0
                        }) {
                            HStack {
                                Image(systemName: status.2)
                                    .foregroundColor(status.3)
                                
                                Text(status.1)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if selectedStatus == status.0 {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.primaryPurple)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filter Live Chats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear") {
                        onClear()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        onApply()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
