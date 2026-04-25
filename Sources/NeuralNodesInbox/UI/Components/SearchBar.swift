import SwiftUI
import Combine

/// Apple-quality search bar with autocomplete and blur overlay
public struct SearchBar: View {
    @Binding var searchText: String
    @Binding var isSearching: Bool
    
    let placeholder: String
    let suggestions: [String]
    let onSuggestionTap: (String) -> Void
    let onSearch: (String) -> Void
    
    @FocusState private var isFocused: Bool
    @State private var showSuggestions = false
    
    public init(
        searchText: Binding<String>,
        isSearching: Binding<Bool>,
        placeholder: String = "Search",
        suggestions: [String] = [],
        onSuggestionTap: @escaping (String) -> Void = { _ in },
        onSearch: @escaping (String) -> Void = { _ in }
    ) {
        self._searchText = searchText
        self._isSearching = isSearching
        self.placeholder = placeholder
        self.suggestions = suggestions
        self.onSuggestionTap = onSuggestionTap
        self.onSearch = onSearch
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 12) {
                // Search icon
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                
                // Text field
                TextField(placeholder, text: $searchText)
                    .font(.system(size: 17))
                    .focused($isFocused)
                    .submitLabel(.search)
                    .onSubmit {
                        onSearch(searchText)
                    }
                    .onChange(of: searchText) { newValue in
                        showSuggestions = !newValue.isEmpty && !suggestions.isEmpty
                    }
                
                // Clear button
                if !searchText.isEmpty {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            searchText = ""
                            showSuggestions = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
                
                // Cancel button (when searching)
                if isSearching {
                    Button("Cancel") {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dismissSearch()
                        }
                    }
                    .font(.system(size: 17))
                    .foregroundColor(.primaryPurple)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(.systemGray6))
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 4)
            .background(Color(.systemBackground))
            
            // Autocomplete suggestions
            if isSearching && showSuggestions && !suggestions.isEmpty {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(suggestions, id: \.self) { suggestion in
                            suggestionRow(suggestion)
                        }
                    }
                }
                .frame(maxHeight: 200)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.1), radius: 8, y: 4)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onChange(of: isFocused) { focused in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isSearching = focused
                if focused {
                    showSuggestions = !searchText.isEmpty && !suggestions.isEmpty
                }
            }
        }
    }
    
    private func suggestionRow(_ suggestion: String) -> some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    searchText = suggestion
                    onSuggestionTap(suggestion)
                    showSuggestions = false
                    isFocused = false
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    Text(suggestion)
                        .font(.system(size: 17))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "arrow.up.left")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            Divider()
                .padding(.leading, 44)
        }
    }
    
    private func dismissSearch() {
        searchText = ""
        showSuggestions = false
        isFocused = false
        isSearching = false
    }
}

// MARK: - Search Results View

public struct SearchResultsView: View {
    let results: [SearchConversationResult]
    let isLoading: Bool
    let onConversationTap: (String) -> Void
    let sdk: NeuralNodesInbox
    
    public init(
        results: [SearchConversationResult],
        isLoading: Bool = false,
        onConversationTap: @escaping (String) -> Void,
        sdk: NeuralNodesInbox
    ) {
        self.results = results
        self.isLoading = isLoading
        self.onConversationTap = onConversationTap
        self.sdk = sdk
    }
    
    public var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if results.isEmpty {
                emptyStateView
            } else {
                resultsList
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Searching...")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No results found")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)
            
            Text("Try adjusting your search")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(results) { result in
                    searchResultRow(result)
                }
            }
        }
    }
    
    private func searchResultRow(_ result: SearchConversationResult) -> some View {
        VStack(spacing: 0) {
            Button(action: {
                onConversationTap(result.id)
            }) {
                HStack(spacing: 12) {
                    // Avatar
                    Circle()
                        .fill(Color.primaryPurple.opacity(0.1))
                        .frame(width: 48, height: 48)
                        .overlay(
                            Text((result.contactName ?? "?").prefix(1).uppercased())
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primaryPurple)
                        )
                    
                    // Content
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(result.contactName ?? result.contactEmail ?? "Unknown")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if result.unreadCount > 0 {
                                Text("\(result.unreadCount)")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.primaryPurple)
                                    .cornerRadius(10)
                            }
                        }
                        
                        if let preview = result.lastMessagePreview {
                            Text(preview)
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        
                        HStack(spacing: 8) {
                            // Channel badge
                            HStack(spacing: 4) {
                                Image(systemName: channelIcon(result.channel))
                                    .font(.system(size: 10))
                                Text(result.channel.capitalized)
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray6))
                            .cornerRadius(6)
                            
                            // Status badge
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(statusColor(result.status))
                                    .frame(width: 6, height: 6)
                                Text(result.status.capitalized)
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray6))
                            .cornerRadius(6)
                        }
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.5))
                }
                .padding(16)
                .background(Color(.systemBackground))
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            Divider()
                .padding(.leading, 76)
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
    
    private func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "active": return .green
        case "pending": return .orange
        case "resolved": return .blue
        case "closed": return .gray
        default: return .gray
        }
    }
}
