import SwiftUI
import Combine

/// ViewModel for search functionality with debouncing
@MainActor
public class SearchViewModel: ObservableObject {
    @Published public var searchText = ""
    @Published public var isSearching = false
    @Published public var suggestions: [String] = []
    @Published public var searchResults: [SearchConversationResult] = []
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    
    private let searchService: SearchService
    private var cancellables = Set<AnyCancellable>()
    private var searchTask: Task<Void, Never>?
    
    public init(searchService: SearchService) {
        self.searchService = searchService
        setupSearchDebouncing()
    }
    
    private func setupSearchDebouncing() {
        // Debounce search text changes
        $searchText
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] query in
                guard let self = self else { return }
                
                if query.isEmpty {
                    self.suggestions = []
                    self.searchResults = []
                    self.isLoading = false
                } else if query.count >= 2 {
                    // Fetch suggestions for autocomplete
                    Task {
                        await self.fetchSuggestions(query: query)
                    }
                    
                    // Perform search
                    Task {
                        await self.performSearch(query: query)
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func fetchSuggestions(query: String) async {
        do {
            let suggestions = try await searchService.getSuggestionsImmediate(query: query, limit: 5)
            await MainActor.run {
                self.suggestions = suggestions
            }
        } catch {
            // Silently fail for suggestions
            await MainActor.run {
                self.suggestions = []
            }
        }
    }
    
    private func performSearch(query: String) async {
        // Cancel previous search
        searchTask?.cancel()
        
        searchTask = Task {
            await MainActor.run {
                isLoading = true
                errorMessage = nil
            }
            
            do {
                let filters = ConversationSearchFilters(
                    query: query,
                    channel: nil,
                    status: nil,
                    limit: 50,
                    offset: 0
                )
                
                let response = try await searchService.searchConversationsImmediate(filters: filters)
                
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    self.searchResults = response.results
                    self.isLoading = false
                }
            } catch {
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    public func selectSuggestion(_ suggestion: String) {
        searchText = suggestion
        suggestions = []
    }
    
    public func clearSearch() {
        searchText = ""
        suggestions = []
        searchResults = []
        isLoading = false
        errorMessage = nil
        searchTask?.cancel()
    }
}
