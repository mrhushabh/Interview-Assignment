import SwiftUI

/// Chat screen for a specific session
/// Shows messages and handles streaming responses
struct ChatView: View {
    
    let session: ChatSession
    @StateObject private var viewModel: ChatViewModel
    
    @State private var messageText = ""
    @FocusState private var isInputFocused: Bool
    
    init(session: ChatSession) {
        self.session = session
        // Initialize view model with session ID
        _viewModel = StateObject(wrappedValue: ChatViewModel(sessionId: session.id))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageBubbleView(message: message)
                                .id(message.id)
                        }
                        
                        // Streaming message (appears while AI is responding)
                        if viewModel.isStreaming && !viewModel.streamingText.isEmpty {
                            StreamingBubbleView(text: viewModel.streamingText)
                                .id("streaming")
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    // Scroll to bottom when new message arrives
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: viewModel.streamingText) { _, _ in
                    // Scroll as streaming text updates
                    scrollToBottom(proxy: proxy)
                }
            }
            
            Divider()
            
            // Input area
            HStack(spacing: 12) {
                // Text field
                TextField("Message", text: $messageText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .focused($isInputFocused)
                    .onSubmit {
                        sendMessage()
                    }
                
                // Send or Cancel button
                if viewModel.isStreaming {
                    // Cancel button (stops streaming)
                    Button {
                        viewModel.cancelStream()
                    } label: {
                        Image(systemName: "stop.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.red)
                    }
                } else {
                    // Send button
                    Button {
                        sendMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(messageText.isEmpty ? .gray : .blue)
                    }
                    .disabled(messageText.isEmpty)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
        }
        .navigationTitle(session.title ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Summarize memory button
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await viewModel.summarizeMemory()
                    }
                } label: {
                    Image(systemName: "brain")
                }
                .disabled(viewModel.messages.isEmpty)
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
            await viewModel.loadMessages()
        }
    }
    
    private func sendMessage() {
        let text = messageText
        messageText = ""
        Task {
            await viewModel.sendMessage(text)
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        if viewModel.isStreaming {
            withAnimation(.easeOut(duration: 0.1)) {
                proxy.scrollTo("streaming", anchor: .bottom)
            }
        } else if let lastMessage = viewModel.messages.last {
            withAnimation(.easeOut(duration: 0.1)) {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
}

/// Message bubble for completed messages
struct MessageBubbleView: View {
    let message: ChatMessage
    
    private var isUser: Bool {
        message.role == .user
    }
    
    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }
            
            Text(message.content)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isUser ? Color.blue : Color(.systemGray5))
                .foregroundStyle(isUser ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 18))
            
            if !isUser { Spacer(minLength: 60) }
        }
    }
}

/// Streaming bubble (shows while AI is responding)
struct StreamingBubbleView: View {
    let text: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(text)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                
                // Typing indicator
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Responding...")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, 8)
            }
            
            Spacer(minLength: 60)
        }
    }
}

#Preview {
    NavigationStack {
        ChatView(session: ChatSession(
            id: UUID(),
            userId: UUID(),
            title: "Test Chat",
            createdAt: Date(),
            updatedAt: Date()
        ))
    }
}
