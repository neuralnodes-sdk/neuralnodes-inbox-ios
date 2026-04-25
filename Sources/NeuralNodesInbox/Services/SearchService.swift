import Foundation
import Combine

/// Search service with debouncing for efficient API calls
public class SearchService {
    
    private let apiClient: APIClient
    private var searchCancellables = Set<AnyCancellable>()
    private let debounceInterval: TimeInterval
    
    // Debounce subjects for different search types
    private let conversationSearchSubject = PassthroughSubject<ConversationSearchFilters, Never>()
    private let messageSearchSubject = PassthroughSubject<MessageSearchFilters, Never>()
    private let suggestionSearchSubject = PassthroughSubject<String, Never>()
    
    public init(apiClient: APIClient, debounceInterval: TimeInterval = 0.3) {
        self.apiClient = apiClient
        self.debounceInterval = debounceInterval
        
        setupDebouncedSearches()
    }
    
    // MARK: - Setup Debouncing
    
    private func setupDebouncedSearches() {
        // Debounced conversation search
        conversationSearchSubject
            .debounce(for: .seconds(debounceInterval), scheduler: DispatchQueue.main)
            .sink { [weak self] filters in
                Task {
                    await self?.performConversationSearch(filters: filters)
                }
            }
            .store(in: &searchCancellables)
        
        // Debounced message search
        messageSearchSubject
            .debounce(for: .seconds(debounceInterval), scheduler: DispatchQueue.main)
            .sink { [weak self] filters in
                Task {
                    await self?.performMessageSearch(filters: filters)
                }
            }
            .store(in: &searchCancellables)
        
        // Debounced suggestion search
        suggestionSearchSubject
            .debounce(for: .seconds(debounceInterval), scheduler: DispatchQueue.main)
            .sink { [weak self] query in
                Task {
                    await self?.performSuggestionSearch(query: query)
                }
            }
            .store(in: &searchCancellables)
    }
    
    // MARK: - Public Search Methods (Debounced)
    
    /// Search conversations with debouncing
    /// - Parameter filters: Search filters
    /// - Returns: Publisher that emits search results
    public func searchConversations(filters: ConversationSearchFilters) -> AnyPublisher<SearchConversationsResponse, Error> {
        let subject = PassthroughSubject<SearchConversationsResponse, Error>()
        
        // Store the subject to receive results
        conversationResultSubjects[filters.query] = subject
        
        // Trigger debounced search
        conversationSearchSubject.send(filters)
        
        return subject.eraseToAnyPublisher()
    }
    
    /// Search messages with debouncing
    /// - Parameter filters: Search filters
    /// - Returns: Publisher that emits search results
    public func searchMessages(filters: MessageSearchFilters) -> AnyPublisher<SearchMessagesResponse, Error> {
        let subject = PassthroughSubject<SearchMessagesResponse, Error>()
        
        // Store the subject to receive results
        messageResultSubjects[filters.query] = subject
        
        // Trigger debounced search
        messageSearchSubject.send(filters)
        
        return subject.eraseToAnyPublisher()
    }
    
    /// Get search suggestions with debouncing
    /// - Parameter query: Search query
    /// - Returns: Publisher that emits suggestions
    public func getSuggestions(query: String) -> AnyPublisher<[String], Error> {
        let subject = PassthroughSubject<[String], Error>()
        
        // Store the subject to receive results
        suggestionResultSubjects[query] = subject
        
        // Trigger debounced search
        suggestionSearchSubject.send(query)
        
        return subject.eraseToAnyPublisher()
    }
    
    // MARK: - Direct API Methods (No Debouncing)
    
    /// Search conversations immediately without debouncing
    public func searchConversationsImmediate(filters: ConversationSearchFilters) async throws -> SearchConversationsResponse {
        return try await apiClient.searchConversations(filters: filters)
    }
    
    /// Search messages in a specific conversation immediately
    public func searchMessagesInConversation(
        conversationId: String,
        query: String,
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> SearchMessagesResponse {
        return try await apiClient.searchMessagesInConversation(
            conversationId: conversationId,
            query: query,
            limit: limit,
            offset: offset
        )
    }
    
    /// Search all messages immediately without debouncing
    public func searchAllMessagesImmediate(filters: MessageSearchFilters) async throws -> SearchMessagesResponse {
        return try await apiClient.searchAllMessages(filters: filters)
    }
    
    /// Get suggestions immediately without debouncing
    public func getSuggestionsImmediate(query: String, limit: Int = 10) async throws -> [String] {
        let response = try await apiClient.getSearchSuggestions(query: query, limit: limit)
        return response.suggestions
    }
    
    // MARK: - Private Implementation
    
    private var conversationResultSubjects = [String: PassthroughSubject<SearchConversationsResponse, Error>]()
    private var messageResultSubjects = [String: PassthroughSubject<SearchMessagesResponse, Error>]()
    private var suggestionResultSubjects = [String: PassthroughSubject<[String], Error>]()
    
    private func performConversationSearch(filters: ConversationSearchFilters) async {
        guard let subject = conversationResultSubjects[filters.query] else { return }
        
        do {
            let response = try await apiClient.searchConversations(filters: filters)
            subject.send(response)
            subject.send(completion: .finished)
        } catch {
            subject.send(completion: .failure(error))
        }
        
        // Clean up
        conversationResultSubjects.removeValue(forKey: filters.query)
    }
    
    private func performMessageSearch(filters: MessageSearchFilters) async {
        guard let subject = messageResultSubjects[filters.query] else { return }
        
        do {
            let response = try await apiClient.searchAllMessages(filters: filters)
            subject.send(response)
            subject.send(completion: .finished)
        } catch {
            subject.send(completion: .failure(error))
        }
        
        // Clean up
        messageResultSubjects.removeValue(forKey: filters.query)
    }
    
    private func performSuggestionSearch(query: String) async {
        guard let subject = suggestionResultSubjects[query] else { return }
        
        do {
            let response = try await apiClient.getSearchSuggestions(query: query, limit: 10)
            subject.send(response.suggestions)
            subject.send(completion: .finished)
        } catch {
            subject.send(completion: .failure(error))
        }
        
        // Clean up
        suggestionResultSubjects.removeValue(forKey: query)
    }
    
    // MARK: - Cancel All Searches
    
    /// Cancel all pending searches
    public func cancelAllSearches() {
        conversationResultSubjects.values.forEach { $0.send(completion: .finished) }
        messageResultSubjects.values.forEach { $0.send(completion: .finished) }
        suggestionResultSubjects.values.forEach { $0.send(completion: .finished) }
        
        conversationResultSubjects.removeAll()
        messageResultSubjects.removeAll()
        suggestionResultSubjects.removeAll()
    }
}
