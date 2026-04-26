import SwiftUI

public struct InboxView: View {
    @StateObject private var viewModel: InboxViewModel
    @StateObject private var searchViewModel: SearchViewModel
    @State private var showChannelFilter = false
    @State private var showStatusFilter = false
    @State private var selectedSearchResult: SearchConversationResult?
    @State private var showInboxSearchConversation = false // Separate boolean for navigation
    @State private var globalSearchNavigation: (conversation: Conversation, searchText: String)?
    @State private var showGlobalSearchConversation = false // Separate boolean for navigation
    @Environment(\.colorScheme) var colorScheme
    
    private let sdk: NeuralNodesInbox
    
    private var isSearchEnabled: Bool {
        sdk.getConfig()?.features.conversationSearch ?? false
    }
    
    public init(sdk: NeuralNodesInbox) {
        self.sdk = sdk
        _viewModel = StateObject(wrappedValue: InboxViewModel(sdk: sdk))
        _searchViewModel = StateObject(wrappedValue: SearchViewModel(searchService: sdk.getSearchService()))
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Search Bar - only show if conversation search is enabled
            if isSearchEnabled {
                SearchBar(
                    searchText: $searchViewModel.searchText,
                    isSearching: $searchViewModel.isSearching,
                    placeholder: "Search conversations",
                    suggestions: searchViewModel.suggestions,
                    onSuggestionTap: { suggestion in
                        searchViewModel.selectSuggestion(suggestion)
                    },
                    onSearch: { _ in }
                )
            }
            
            // Show search results or normal inbox
            if isSearchEnabled && searchViewModel.isSearching && !searchViewModel.searchText.isEmpty {
                SearchResultsView(
                    results: searchViewModel.searchResults,
                    isLoading: searchViewModel.isLoading,
                    onConversationTap: { conversationId in
                        // Find the search result and convert to conversation
                        if let result = searchViewModel.searchResults.first(where: { $0.id == conversationId }) {
                            selectedSearchResult = result
                            // Trigger navigation with a slight delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                showInboxSearchConversation = true
                                // Clear search after navigation is triggered
                                searchViewModel.clearSearch()
                            }
                        }
                    },
                    sdk: sdk
                )
            } else {
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
                                .simultaneousGesture(TapGesture().onEnded {
                                    // Pause real-time updates when navigating to conversation
                                    viewModel.pauseRealtimeUpdates()
                                })
                                
                                // Bottom border for each conversation card
                                Divider()
                                    .padding(.leading, 82)
                            }
                        }
                        .padding(.vertical, 8)
                    }
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
            // Only resume if we're not already subscribed
            if !viewModel.isSubscribed {
                print("👁️ [INBOX VIEW] onAppear - resuming real-time updates")
                viewModel.resumeRealtimeUpdates()
                
                Task {
                    await viewModel.loadConversations()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshInboxAndDismiss"))) { _ in
            print("📢 [INBOX VIEW] Received RefreshInboxAndDismiss notification")
            Task {
                await viewModel.loadConversations()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshInboxList"))) { _ in
            print("📢 [INBOX VIEW] Received RefreshInboxList notification")
            // Use debounced version to prevent infinite loops
            Task {
                await viewModel.loadConversationsWithDebounce()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToConversationWithSearch"))) { notification in
            if let userInfo = notification.userInfo,
               let conversation = userInfo["conversation"] as? Conversation,
               let searchText = userInfo["searchText"] as? String {
                globalSearchNavigation = (conversation, searchText)
                // Trigger navigation with a slight delay to ensure state is set
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showGlobalSearchConversation = true
                }
            }
        }
        .overlay(
            Group {
                // Navigation for inbox search results
                if let result = selectedSearchResult {
                    NavigationLink(
                        destination: ConversationDetailView(
                            conversation: convertToConversation(result),
                            sdk: sdk
                        ),
                        isActive: $showInboxSearchConversation,
                        label: { EmptyView() }
                    )
                    .opacity(0)
                    .onChange(of: showInboxSearchConversation) { newValue in
                        if !newValue {
                            selectedSearchResult = nil
                        }
                    }
                }
                
                // Navigation for global search results
                if let nav = globalSearchNavigation {
                    NavigationLink(
                        destination: ConversationDetailView(
                            conversation: nav.conversation,
                            sdk: sdk,
                            initialSearchText: nav.searchText
                        ),
                        isActive: $showGlobalSearchConversation,
                        label: { EmptyView() }
                    )
                    .opacity(0)
                    .onChange(of: showGlobalSearchConversation) { newValue in
                        if !newValue {
                            globalSearchNavigation = nil
                        }
                    }
                }
            }
        )
    }
    
    // MARK: - Helper Methods
    
    /// Convert SearchConversationResult to Conversation for navigation
    private func convertToConversation(_ result: SearchConversationResult) -> Conversation {
        // Create a Conversation from the search result
        // Note: We use current date for createdAt/updatedAt since search results don't include them
        let now = Date()
        
        return Conversation(
            id: result.id,
            channel: result.channel,
            contactName: result.contactName,
            contactEmail: result.contactEmail,
            contactPhone: result.contactPhone,
            lastMessagePreview: result.lastMessagePreview,
            unreadCount: result.unreadCount,
            status: result.status,
            lastMessageAt: result.lastMessageAt,
            createdAt: now,
            updatedAt: result.lastMessageAt ?? now
        )
    }
}
