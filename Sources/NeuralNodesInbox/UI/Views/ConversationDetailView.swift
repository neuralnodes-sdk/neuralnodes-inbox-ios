import SwiftUI

public struct ConversationDetailView: View {
    public let conversation: Conversation
    @StateObject private var viewModel: ConversationDetailViewModel
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode
    
    // In-chat search state
    @State private var isSearching = false
    @State private var searchText = ""
    @State private var searchResults: [String] = [] // Message IDs that match
    @State private var currentSearchIndex = 0
    @State private var searchInAllConversations = false // Toggle for global search
    @State private var globalSearchResults: [SearchMessageResult] = [] // Results from global search
    @State private var isLoadingGlobalSearch = false
    @State private var showGlobalSearchResults = false // Control sheet visibility
    @State private var searchDebounceTimer: Timer?
    @State private var selectedGlobalResult: SearchMessageResult? // For navigation
    @State private var navigateToConversation: Conversation? // Trigger navigation
    @FocusState private var searchFieldFocused: Bool
    
    private let sdk: NeuralNodesInbox
    
    public init(conversation: Conversation, sdk: NeuralNodesInbox, initialSearchText: String? = nil) {
        self.conversation = conversation
        self.sdk = sdk
        _viewModel = StateObject(wrappedValue: ConversationDetailViewModel(
            conversationId: conversation.id,
            conversationStatus: conversation.status,
            sdk: sdk
        ))
        
        // Pre-fill search if provided
        if let searchText = initialSearchText, !searchText.isEmpty {
            _isSearching = State(initialValue: true)
            _searchText = State(initialValue: searchText)
        }
    }
    
    private var isInputDisabled: Bool {
        conversation.status == "resolved" || conversation.status == "closed"
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Search scope toggle (shown when searching)
            if isSearching {
                searchScopeToggle
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            // Messages List
            ScrollViewReader { proxy in
                GeometryReader { geometry in
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(spacing: 16) {
                            // Load more indicator at top (only show if scrolled up and has more)
                            if viewModel.hasMoreMessages && !viewModel.isLoading && viewModel.messages.count >= 15 {
                                HStack {
                                    if viewModel.isLoadingMore {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                            .padding(.vertical, 8)
                                    } else {
                                        Color.clear
                                            .frame(height: 1)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .id("loadMoreTrigger")
                                .onAppear {
                                    Task {
                                        await viewModel.loadMoreMessages()
                                    }
                                }
                            }
                            
                            ForEach(viewModel.messages) { message in
                                MessageBubble(
                                    message: message,
                                    searchText: isSearching ? searchText : nil,
                                    isHighlighted: searchResults.indices.contains(currentSearchIndex) && 
                                                   searchResults[currentSearchIndex] == message.id
                                )
                                .id(message.id)
                            }
                        }
                        .padding()
                        .frame(minHeight: geometry.size.height, alignment: .bottom)
                    }
                    .background(colorScheme == .dark ? Color.black : Color(.systemGroupedBackground))
                }
                .onChange(of: viewModel.scrollToMessageId) { messageId in
                    if let messageId = messageId {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo(messageId, anchor: .bottom)
                            }
                        }
                    }
                }
                .onChange(of: currentSearchIndex) { _ in
                    scrollToCurrentSearchResult(proxy: proxy)
                }
                .onChange(of: searchText) { newValue in
                    // Cancel previous timer
                    searchDebounceTimer?.invalidate()
                    
                    // Create new timer for debouncing
                    searchDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: false) { _ in
                        performSearch(query: newValue)
                    }
                }
                .onChange(of: viewModel.messages.count) { oldCount in
                    let newCount = viewModel.messages.count
                    
                    // If loading more (messages added at beginning), don't scroll
                    if viewModel.isLoadingMore {
                        return
                    }
                    
                    // Scroll to bottom when new messages are added (including first load)
                    if newCount > oldCount, let lastMessage = viewModel.messages.last {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            
            // Input Bar - Fixed at bottom
            Divider()
            
            if isInputDisabled {
                // Disabled state for resolved/closed conversations
                HStack {
                    Text(conversation.status == "closed" ? "This conversation is closed" : "This conversation is resolved")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
                .padding()
                .background(colorScheme == .dark ? Color.black : Color.white)
            } else {
                MessageInputBar(
                    text: $viewModel.messageText,
                    onSend: {
                        Task {
                            await viewModel.sendMessage()
                        }
                    }
                )
                .background(colorScheme == .dark ? Color.black : Color.white)
            }
        }
        .navigationBarHidden(false)
        .navigationBarBackButtonHidden(false)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshInboxAndDismiss"))) { _ in
            presentationMode.wrappedValue.dismiss()
        }
        .navigationTitle(isSearching ? "" : conversation.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            // Custom title view when searching
            if isSearching {
                ToolbarItem(placement: .principal) {
                    inChatSearchBar
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                if isSearching {
                    searchNavigationButtons
                } else {
                    conversationMenu
                }
            }
        }
        .alert(isPresented: $viewModel.showError) {
            Alert(
                title: Text("Error"),
                message: Text(viewModel.errorMessage ?? "An error occurred"),
                dismissButton: .default(Text("OK"))
            )
        }
        .task {
            await viewModel.loadMessages()
            viewModel.markAsRead()
            viewModel.startListening()
        }
        .onDisappear {
            viewModel.stopListening()
            searchDebounceTimer?.invalidate()
        }
        .sheet(isPresented: $showGlobalSearchResults) {
            NavigationStack {
                globalSearchResultsView
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }
    
    // MARK: - In-Chat Search Components
    
    /// Search bar that replaces the navigation title
    private var inChatSearchBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                
                TextField(searchInAllConversations ? "Search all conversations" : "Search in conversation", text: $searchText)
                    .font(.system(size: 16))
                    .focused($searchFieldFocused)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        searchResults = []
                        globalSearchResults = []
                        currentSearchIndex = 0
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            Button("Cancel") {
                withAnimation(.spring(response: 0.3)) {
                    isSearching = false
                    searchText = ""
                    searchResults = []
                    globalSearchResults = []
                    currentSearchIndex = 0
                    searchInAllConversations = false
                    showGlobalSearchResults = false
                    searchFieldFocused = false
                }
            }
            .font(.system(size: 16))
            .foregroundColor(.primaryPurple)
        }
        .padding(.horizontal, 8)
        .onAppear {
            searchFieldFocused = true
        }
    }
    
    /// Search scope toggle (This Chat vs All Chats)
    private var searchScopeToggle: some View {
        HStack(spacing: 12) {
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    searchInAllConversations = false
                    // Re-trigger search with new scope
                    if !searchText.isEmpty {
                        performSearch(query: searchText)
                    }
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: searchInAllConversations ? "circle" : "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("This Chat")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(searchInAllConversations ? .secondary : .primaryPurple)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(searchInAllConversations ? Color(.systemGray6) : Color.primaryPurple.opacity(0.1))
                )
            }
            
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    searchInAllConversations = true
                    // Re-trigger search with new scope
                    if !searchText.isEmpty {
                        performSearch(query: searchText)
                    }
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: searchInAllConversations ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 14, weight: .semibold))
                    Text("All Chats")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(searchInAllConversations ? .primaryPurple : .secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(searchInAllConversations ? Color.primaryPurple.opacity(0.1) : Color(.systemGray6))
                )
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .overlay(
            Divider(), alignment: .bottom
        )
    }
    
    /// Navigation buttons for search results (previous/next + counter)
    private var searchNavigationButtons: some View {
        HStack(spacing: 12) {
            if !searchResults.isEmpty && !searchInAllConversations {
                // Match counter
                Text("\(currentSearchIndex + 1) of \(searchResults.count)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                
                // Previous button
                Button(action: navigateToPreviousResult) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(currentSearchIndex > 0 ? .primaryPurple : .secondary.opacity(0.5))
                }
                .disabled(currentSearchIndex == 0)
                
                // Next button
                Button(action: navigateToNextResult) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(currentSearchIndex < searchResults.count - 1 ? .primaryPurple : .secondary.opacity(0.5))
                }
                .disabled(currentSearchIndex >= searchResults.count - 1)
            }
        }
    }
    
    /// Conversation menu (three dots)
    private var conversationMenu: some View {
        Menu {
            // Search in conversation
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    isSearching = true
                }
            }) {
                Label("Search in Conversation", systemImage: "magnifyingglass")
            }
            
            Divider()
            
            // For closed conversations: Only show Reopen
            if conversation.status == "closed" {
                Button(action: {
                    Task {
                        await viewModel.updateStatus(to: "active")
                    }
                }) {
                    Label("Reopen Chat", systemImage: "arrow.clockwise.circle.fill")
                }
            } else {
                // For other statuses: Show Mark as Read (except resolved)
                if conversation.status != "resolved" {
                    Button(action: { viewModel.markAsRead() }) {
                        Label("Mark as Read", systemImage: "envelope.open.fill")
                    }
                    
                    Divider()
                }
                
                // Show different options based on current status
                if conversation.status != "active" {
                    Button(action: {
                        Task {
                            await viewModel.updateStatus(to: "active")
                        }
                    }) {
                        Label("Mark as Active", systemImage: "circle.fill")
                    }
                }
                
                if conversation.status != "pending" {
                    Button(action: {
                        Task {
                            await viewModel.updateStatus(to: "pending")
                        }
                    }) {
                        Label("Mark as Pending", systemImage: "clock.fill")
                    }
                }
                
                if conversation.status != "resolved" {
                    Button(action: {
                        Task {
                            await viewModel.updateStatus(to: "resolved")
                        }
                    }) {
                        Label("Mark as Resolved", systemImage: "checkmark.circle.fill")
                    }
                }
                
                if conversation.status == "resolved" {
                    Button(action: {
                        Task {
                            await viewModel.updateStatus(to: "closed")
                        }
                    }) {
                        Label("Mark as Closed", systemImage: "xmark.circle.fill")
                    }
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle.fill")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(Color(hex: "#667eea"))
        }
    }
    
    // MARK: - Search Functions
    
    /// Perform search in messages (local or global)
    private func performSearch(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            globalSearchResults = []
            currentSearchIndex = 0
            return
        }
        
        if searchInAllConversations {
            // Global search across all conversations
            performGlobalSearch(query: query)
        } else {
            // Local search in current conversation
            let lowercasedQuery = query.lowercased()
            searchResults = viewModel.messages
                .filter { $0.messageText.lowercased().contains(lowercasedQuery) }
                .map { $0.id }
            
            currentSearchIndex = searchResults.isEmpty ? 0 : 0
            
            // Scroll to first result if found
            if !searchResults.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // Trigger scroll via currentSearchIndex change
                    currentSearchIndex = 0
                }
            }
        }
    }
    
    /// Perform global search across all conversations
    private func performGlobalSearch(query: String) {
        isLoadingGlobalSearch = true
        globalSearchResults = []
        showGlobalSearchResults = true // Show the sheet
        
        Task {
            do {
                let searchService = sdk.getSearchService()
                let filters = MessageSearchFilters(
                    query: query,
                    channel: nil,
                    senderType: nil,
                    dateFrom: nil,
                    dateTo: nil,
                    limit: 50,
                    offset: 0
                )
                
                let response = try await searchService.searchAllMessagesImmediate(filters: filters)
                
                await MainActor.run {
                    self.globalSearchResults = response.results
                    self.isLoadingGlobalSearch = false
                }
            } catch {
                await MainActor.run {
                    self.isLoadingGlobalSearch = false
                    print("❌ Global search error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Navigate to next search result
    private func navigateToNextResult() {
        guard currentSearchIndex < searchResults.count - 1 else { return }
        currentSearchIndex += 1
    }
    
    /// Navigate to previous search result
    private func navigateToPreviousResult() {
        guard currentSearchIndex > 0 else { return }
        currentSearchIndex -= 1
    }
    
    /// Scroll to current search result
    private func scrollToCurrentSearchResult(proxy: ScrollViewProxy) {
        guard searchResults.indices.contains(currentSearchIndex) else { return }
        let messageId = searchResults[currentSearchIndex]
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 0.3)) {
                proxy.scrollTo(messageId, anchor: .center)
            }
        }
    }
    
    // MARK: - Global Search Results View
    
    /// View showing global search results across all conversations
    private var globalSearchResultsView: some View {
        Group {
            if isLoadingGlobalSearch {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Searching all conversations...")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if globalSearchResults.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No messages found")
                        .font(.system(size: 20, weight: .semibold))
                    Text("Try a different search term")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(globalSearchResults) { result in
                            globalSearchResultRow(result)
                        }
                    }
                }
            }
        }
        .navigationTitle("Search Results")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    showGlobalSearchResults = false
                }
                .foregroundColor(.primaryPurple)
            }
        }
    }
    
    /// Row for global search result
    private func globalSearchResultRow(_ result: SearchMessageResult) -> some View {
        VStack(spacing: 0) {
            Button(action: {
                // Check if this is the same conversation we're already in
                if result.conversationId == conversation.id {
                    // Same conversation - just close sheet and activate search
                    showGlobalSearchResults = false
                    isSearching = true
                    searchInAllConversations = false
                    // Trigger search with current text
                    performSearch(query: searchText)
                } else {
                    // Different conversation - navigate to it
                    let targetConversation = Conversation(
                        id: result.conversationId,
                        channel: result.channel ?? "unknown",
                        contactName: result.contactName,
                        contactEmail: result.contactEmail,
                        contactPhone: result.contactPhone,
                        lastMessagePreview: result.messageText,
                        unreadCount: 0,
                        status: result.conversationStatus ?? "active",
                        lastMessageAt: result.createdAt,
                        createdAt: result.createdAt,
                        updatedAt: result.createdAt
                    )
                    
                    // Close sheet and search mode
                    showGlobalSearchResults = false
                    isSearching = false
                    
                    // First, dismiss current conversation
                    presentationMode.wrappedValue.dismiss()
                    
                    // Then trigger navigation to new conversation with delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        let userInfo: [String: Any] = [
                            "conversation": targetConversation,
                            "searchText": searchText
                        ]
                        
                        NotificationCenter.default.post(
                            name: NSNotification.Name("NavigateToConversationWithSearch"),
                            object: nil,
                            userInfo: userInfo
                        )
                    }
                }
            }) {
                VStack(alignment: .leading, spacing: 8) {
                    // Contact info
                    HStack {
                        Circle()
                            .fill(Color.primaryPurple.opacity(0.1))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text((result.contactName ?? "?").prefix(1).uppercased())
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primaryPurple)
                            )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.contactName ?? result.contactEmail ?? "Unknown")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            if let channel = result.channel {
                                HStack(spacing: 4) {
                                    Image(systemName: channelIcon(channel))
                                        .font(.system(size: 10))
                                    Text(channel.capitalized)
                                        .font(.system(size: 12))
                                }
                                .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Text(formatDate(result.createdAt))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    // Message text with highlight
                    Text(result.messageText)
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                        .lineLimit(3)
                        .padding(.leading, 48)
                    
                    // Sender info
                    HStack(spacing: 4) {
                        Image(systemName: result.senderType == "user" ? "person.fill" : "person.badge.shield.checkmark.fill")
                            .font(.system(size: 10))
                        Text(result.senderName ?? result.senderType.capitalized)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                    .padding(.leading, 48)
                }
                .padding(16)
                .background(Color(.systemBackground))
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            Divider()
                .padding(.leading, 64)
        }
    }
    
    private func channelIcon(_ channel: String) -> String {
        switch channel.lowercased() {
        case "whatsapp": return "message.badge.filled.fill"
        case "telegram": return "paperplane.fill"
        case "email": return "envelope.fill"
        default: return "message.fill"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
