import SwiftUI

public struct LiveChatView: View {
    public let escalation: Escalation
    @StateObject private var viewModel: LiveChatViewModel
    @State private var showConnectionBanner = false
    
    private let sdk: NeuralNodesInbox
    
    public init(escalation: Escalation, sdk: NeuralNodesInbox) {
        self.escalation = escalation
        self.sdk = sdk
        _viewModel = StateObject(wrappedValue: LiveChatViewModel(escalationId: escalation.id, sdk: sdk))
    }
    
    // Check if chat is closed or resolved
    private var isChatClosed: Bool {
        let status = escalation.status.lowercased()
        return status == "closed" || status == "resolved"
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Connection Status Banner
            if !viewModel.isConnected {
                ConnectionStatusBanner()
            }
            
            // Messages List
            ScrollViewReader { proxy in
                GeometryReader { geometry in
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
                        .frame(minHeight: geometry.size.height, alignment: .bottom)
                    }
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
                    // Only show End Chat if not already closed
                    if !isChatClosed {
                        Button(action: { viewModel.endChat() }) {
                            Label("End Chat", systemImage: "xmark.circle")
                        }
                    }
                    
                    Button(action: { viewModel.transferChat() }) {
                        Label("Transfer Chat", systemImage: "arrow.right.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
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
