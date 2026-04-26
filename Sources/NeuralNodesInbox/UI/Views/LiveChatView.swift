import SwiftUI

public struct LiveChatView: View {
    public let escalation: Escalation
    @StateObject private var viewModel: LiveChatViewModel
    @State private var showConnectionBanner = false
    @State private var showResolveDialog = false
    @State private var showEndChatDialog = false
    @State private var showReopenDialog = false
    @State private var resolutionNotes = ""
    @State private var endChatReason = ""
    @Environment(\.dismiss) private var dismiss
    
    private let sdk: NeuralNodesInbox
    
    public init(escalation: Escalation, sdk: NeuralNodesInbox) {
        self.escalation = escalation
        self.sdk = sdk
        _viewModel = StateObject(wrappedValue: LiveChatViewModel(escalationId: escalation.id, sdk: sdk))
    }
    
    // Check if chat is closed or resolved
    private var isChatClosed: Bool {
        let status = viewModel.currentStatus.lowercased()
        return status == "closed" || status == "resolved"
    }
    
    private var currentStatus: String {
        viewModel.currentStatus.lowercased()
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Connection Status Banner
            if !viewModel.isConnected {
                ConnectionStatusBanner()
            }
            
            // Messages List
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 12) {
                        // Load more indicator at top
                        if viewModel.hasMoreMessages && viewModel.messages.count >= 15 {
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
                                // Only load more if we already have messages (not initial load)
                                if !viewModel.messages.isEmpty {
                                    Task {
                                        await viewModel.loadMoreMessages()
                                    }
                                }
                            }
                        }
                        
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.scrollToMessageId) { messageId in
                    if let messageId = messageId {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation {
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
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            
            // Typing Indicator
            if viewModel.isTyping {
                TypingIndicator()
                    .background(Color(.systemBackground))
            }
            
            // Input Bar - Fixed at bottom
            Divider()
            
            // Only show input if chat is not closed
            if !isChatClosed {
                MessageInputBar(
                    text: $viewModel.messageText,
                    onSend: {
                        Task {
                            await viewModel.sendMessage()
                        }
                    }
                )
                .background(Color(.systemBackground))
            } else {
                // Disabled input for closed chats
                HStack {
                    Text("This conversation has been closed")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .background(Color(.systemGray6))
            }
        }
        .navigationBarHidden(false)
        .navigationBarBackButtonHidden(false)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .navigationTitle(escalation.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    // Status-based menu options
                    if currentStatus == "pending" {
                        Button(action: { 
                            Task {
                                await viewModel.acceptChat()
                                if viewModel.currentStatus.lowercased() == "active" {
                                    // Successfully accepted
                                }
                            }
                        }) {
                            Label("Accept Chat", systemImage: "checkmark.circle")
                        }
                    }
                    
                    if currentStatus == "active" {
                        Button(action: { 
                            showResolveDialog = true
                        }) {
                            Label("Resolve", systemImage: "checkmark.circle.fill")
                        }
                        
                        Button(action: { 
                            showEndChatDialog = true
                        }) {
                            Label("End Chat", systemImage: "xmark.circle")
                        }
                    }
                    
                    if currentStatus == "resolved" {
                        Button(action: { 
                            Task {
                                await viewModel.closeChat()
                            }
                        }) {
                            Label("Close", systemImage: "xmark.circle.fill")
                        }
                        
                        Button(action: { 
                            showReopenDialog = true
                        }) {
                            Label("Reopen", systemImage: "arrow.counterclockwise")
                        }
                    }
                    
                    Divider()
                    
                    Button(action: { viewModel.transferChat() }) {
                        Label("Transfer Chat", systemImage: "arrow.right.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Resolve Chat", isPresented: $showResolveDialog) {
            TextField("Resolution notes (optional)", text: $resolutionNotes, axis: .vertical)
                .lineLimit(3...6)
            
            Button("Cancel", role: .cancel) {
                resolutionNotes = ""
            }
            
            Button("Resolve") {
                Task {
                    await viewModel.resolveChat(notes: resolutionNotes.isEmpty ? nil : resolutionNotes)
                    resolutionNotes = ""
                    // Dismiss after successful resolve
                    dismiss()
                }
            }
        } message: {
            Text("Add optional notes about how this issue was resolved.")
        }
        .alert("End Chat", isPresented: $showEndChatDialog) {
            TextField("Reason for ending (optional)", text: $endChatReason, axis: .vertical)
                .lineLimit(3...6)
            
            Button("Cancel", role: .cancel) {
                endChatReason = ""
            }
            
            Button("End Chat", role: .destructive) {
                Task {
                    await viewModel.endChat(reason: endChatReason.isEmpty ? "Chat ended by agent" : endChatReason)
                    endChatReason = ""
                    // Dismiss after successful end chat
                    dismiss()
                }
            }
        } message: {
            Text("This will close the chat. You can optionally provide a reason.")
        }
        .alert("Reopen Chat", isPresented: $showReopenDialog) {
            Button("Cancel", role: .cancel) {}
            
            Button("Reopen") {
                Task {
                    await viewModel.reopenChat()
                }
            }
        } message: {
            Text("This will reopen the chat and set it back to active status.")
        }
        .task {
            await viewModel.connect()
            await viewModel.loadMessages()
        }
        .onDisappear {
            viewModel.disconnect()
        }
    }
}

struct ConnectionStatusBanner: View {
    var body: some View {
        HStack {
            Image(systemName: "wifi.slash")
                .font(.system(size: 14))
            Text("Reconnecting...")
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.warningYellow)
    }
}

struct TypingIndicator: View {
    @State private var animating = false
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.gray)
                    .frame(width: 6, height: 6)
                    .scaleEffect(animating ? 1.0 : 0.5)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: animating
                    )
            }
            Text("Customer is typing...")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .onAppear {
            animating = true
        }
    }
}
