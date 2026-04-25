import SwiftUI

public struct InboxView: View {
    @StateObject private var viewModel: InboxViewModel
    @State private var showChannelFilter = false
    @State private var showStatusFilter = false
    @Environment(\.colorScheme) var colorScheme
    
    private let sdk: NeuralNodesInbox
    
    public init(sdk: NeuralNodesInbox) {
        self.sdk = sdk
        _viewModel = StateObject(wrappedValue: InboxViewModel(sdk: sdk))
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Filter Bar
            FilterBar(
                selectedChannel: $viewModel.selectedChannel,
                selectedStatus: $viewModel.selectedStatus,
                onChannelTap: { showChannelFilter = true },
                onStatusTap: { showStatusFilter = true }
            )
            
            // Conversation List
            if viewModel.isLoading && viewModel.conversations.isEmpty {
                LoadingView()
            } else if viewModel.conversations.isEmpty {
                EmptyStateView(
                    icon: "tray",
                    title: "No Conversations",
                    message: "There are no conversations matching your filters"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.conversations) { conversation in
                            NavigationLink(destination: ConversationDetailView(conversation: conversation, sdk: sdk)) {
                                ConversationRow(conversation: conversation)
                                    .padding(.horizontal, 16)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            if conversation.id != viewModel.conversations.last?.id {
                                Divider()
                                    .padding(.leading, 82)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .navigationTitle("Inbox")
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.visible, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { Task { await viewModel.loadConversations() } }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "#667eea"))
                }
            }
        }
        .sheet(isPresented: $showChannelFilter) {
            FilterSheet(
                title: "Filter by Channel",
                options: Channel.allCases,
                selectedOption: $viewModel.selectedChannel
            )
        }
        .sheet(isPresented: $showStatusFilter) {
            FilterSheet(
                title: "Filter by Status",
                options: ConversationStatus.allCases,
                selectedOption: $viewModel.selectedStatus
            )
        }
        .alert(isPresented: $viewModel.showError) {
            Alert(
                title: Text("Error"),
                message: Text(viewModel.errorMessage ?? "An error occurred"),
                primaryButton: .default(Text("Retry")) {
                    Task { await viewModel.loadConversations() }
                },
                secondaryButton: .cancel()
            )
        }
        .onAppear {
            Task {
                await viewModel.loadConversations()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshInboxAndDismiss"))) { _ in
            Task {
                await viewModel.loadConversations()
            }
        }
    }
}
