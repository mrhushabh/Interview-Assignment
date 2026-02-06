import SwiftUI

/// Main screen showing list of chat sessions
struct SessionsView: View {
    
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = SessionsViewModel()
    
    @State private var showingNewSession = false
    @State private var newSessionTitle = ""
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.sessions.isEmpty {
                    // Initial loading state
                    ProgressView("Loading sessions...")
                } else if viewModel.sessions.isEmpty {
                    // Empty state
                    ContentUnavailableView(
                        "No Conversations",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text("Tap + to start a new conversation")
                    )
                } else {
                    // Sessions list
                    List {
                        ForEach(viewModel.sessions) { session in
                            NavigationLink(destination: ChatView(session: session)) {
                                SessionRowView(session: session)
                            }
                        }
                        .onDelete(perform: deleteSessions)
                    }
                    .refreshable {
                        await viewModel.loadSessions()
                    }
                }
            }
            .navigationTitle("Chats")
            .toolbar {
                // Sign out button
                ToolbarItem(placement: .topBarLeading) {
                    Button("Sign Out") {
                        Task {
                            await authViewModel.signOut()
                        }
                    }
                }
                
                // New session button
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewSession = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("New Conversation", isPresented: $showingNewSession) {
                TextField("Title (optional)", text: $newSessionTitle)
                Button("Cancel", role: .cancel) {
                    newSessionTitle = ""
                }
                Button("Create") {
                    Task {
                        let title = newSessionTitle.isEmpty ? nil : newSessionTitle
                        await viewModel.createSession(title: title)
                        newSessionTitle = ""
                    }
                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
            .task {
                await viewModel.loadSessions()
            }
        }
    }
    
    private func deleteSessions(at offsets: IndexSet) {
        for index in offsets {
            let session = viewModel.sessions[index]
            Task {
                await viewModel.deleteSession(session)
            }
        }
    }
}

/// Row view for a single session in the list
struct SessionRowView: View {
    let session: ChatSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.title ?? "Untitled Conversation")
                .font(.headline)
                .lineLimit(1)
            
            Text(session.updatedAt, style: .relative)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SessionsView()
        .environmentObject(AuthViewModel())
}
