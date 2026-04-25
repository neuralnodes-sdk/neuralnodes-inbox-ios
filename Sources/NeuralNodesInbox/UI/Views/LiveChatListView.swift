import SwiftUI

public struct LiveChatListView: View {
    @StateObject private var viewModel: LiveChatListViewModel
    
    private let sdk: NeuralNodesInbox
    
    public init(sdk: NeuralNodesInbox) {
        self.sdk = sdk
        _viewModel = StateObject(wrappedValue: LiveChatListViewModel(sdk: sdk))
    }
    
    public var body: some View {
        VStack {
            if viewModel.isLoading && viewModel.escalations.isEmpty {
                LoadingView()
            } else if viewModel.escalations.isEmpty {
                EmptyStateView(
                    icon: "message.badge",
                    title: "No Live Chats",
                    message: "Active escalations will appear here"
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
                Button(action: { Task { await viewModel.loadEscalations() } }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.loadEscalations()
            }
        }
    }
}
