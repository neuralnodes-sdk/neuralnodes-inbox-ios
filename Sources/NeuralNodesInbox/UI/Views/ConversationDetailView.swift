import SwiftUI

public struct ConversationDetailView: View {
    public let conversation: Conversation
    @StateObject private var viewModel: ConversationDetailViewModel
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode
    
    private let sdk: NeuralNodesInbox
    
    public init(conversation: Conversation, sdk: NeuralNodesInbox) {
        self.conversation = conversation
        self.sdk = sdk
        _viewModel = StateObject(wrappedValue: ConversationDetailViewModel(
            conversationId: conversation.id,
            conversationStatus: conversation.status,
            sdk: sdk
        ))
    }
    
    private var isInputDisabled: Bool {
        conversation.status == "resolved" || conversation.status == "closed"
    }
    
    public var body: some View {
        VStack(spacing: 0) {
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
                                MessageBubble(message: message)
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
        .navigationTitle(conversation.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
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
        }
    }
}
