import Foundation
import Combine
import Supabase

/// ViewModel for chat functionality
/// Handles message sending, streaming responses, and memory summarization
@MainActor
final class ChatViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// All messages in the current session
    @Published var messages: [ChatMessage] = []
    
    /// Whether messages are being loaded
    @Published var isLoading = false
    
    /// Whether a response is currently streaming
    @Published var isStreaming = false
    
    /// The text being streamed (shown in UI while streaming)
    @Published var streamingText = ""
    
    /// Error message to display
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    
    /// The session ID this view model is managing
    private let sessionId: UUID
    
    /// Task for the current streaming operation (allows cancellation)
    private var streamingTask: Task<Void, Never>?
    
    private var supabase: SupabaseClient {
        SupabaseService.shared.client
    }

    
    init(sessionId: UUID) {
        self.sessionId = sessionId
    }

    
    /// Load all messages for this session
    func loadMessages() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response: [ChatMessage] = try await supabase
                .from("chat_messages")
                .select()
                .eq("session_id", value: sessionId)
                .order("created_at", ascending: true)
                .execute()
                .value
            
            messages = response
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    /// Send a message and stream the response

    func sendMessage(_ text: String) async {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        // Cancel any existing stream
        cancelStream()
        

        let userMessage = ChatMessage(
            id: UUID(),
            sessionId: sessionId,
            role: .user,
            content: trimmedText,
            createdAt: Date()
        )
        messages.append(userMessage)
        
        // Start streaming response
        await streamResponse(message: trimmedText)
    }
    
    /// Cancel the current streaming operation
    func cancelStream() {
        streamingTask?.cancel()
        streamingTask = nil
        
 
        if !streamingText.isEmpty {
            let partialMessage = ChatMessage(
                id: UUID(),
                sessionId: sessionId,
                role: .assistant,
                content: streamingText.trimmingCharacters(in: .whitespacesAndNewlines),
                createdAt: Date()
            )
            messages.append(partialMessage)
            streamingText = ""
        }
        
        isStreaming = false
    }
    
    /// Create a memory summary for this session
    func summarizeMemory() async {
        errorMessage = nil
        
        do {
            // Get auth token
            let session = try await supabase.auth.session
            let accessToken = session.accessToken
            
            // Build request
            let url = SupabaseService.shared.edgeFunctionURL("summarize_memory")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(SupabaseService.shared.anonKey, forHTTPHeaderField: "apikey")
            
            let body = ["session_id": sessionId.uuidString]
            request.httpBody = try JSONEncoder().encode(body)
            
            // Send request
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let memory = json["memory"] as? [String: Any],
               let summary = memory["summary"] as? String {
                print("Memory created: \(summary)")
            }
            
        } catch {
            errorMessage = "Failed to create memory: \(error.localizedDescription)"
        }
    }
    
    
    /// Stream response from the chat_stream Edge Function
    private func streamResponse(message: String) async {
        isStreaming = true
        streamingText = ""
        errorMessage = nil
        
        streamingTask = Task {
            do {
                // Get auth token
                let session = try await supabase.auth.session
                let accessToken = session.accessToken
                
                // Build request
                let url = SupabaseService.shared.edgeFunctionURL("chat_stream")
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue(SupabaseService.shared.anonKey, forHTTPHeaderField: "apikey")
                
                let body: [String: String] = [
                    "session_id": sessionId.uuidString,
                    "message": message
                ]
                request.httpBody = try JSONEncoder().encode(body)
                
                // Start streaming request
                let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }
                
                // Process SSE stream
                var buffer = ""
                
                for try await byte in asyncBytes {
                    // Check for cancellation
                    if Task.isCancelled { break }
                    
                    
                    let char = Character(UnicodeScalar(byte))
                    buffer.append(char)
                    
            
                    while buffer.contains("\n\n") {
                        guard let range = buffer.range(of: "\n\n") else { break }
                        
                        let line = String(buffer[..<range.lowerBound])
                        buffer = String(buffer[range.upperBound...])
                        
                        // Parse SSE data line
                        if line.hasPrefix("data: ") {
                            let jsonString = String(line.dropFirst(6))
                            
                            if let data = jsonString.data(using: .utf8),
                               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                                
                                // Check for error
                                if let error = json["error"] as? String {
                                    throw NSError(domain: "ChatError", code: -1, 
                                                  userInfo: [NSLocalizedDescriptionKey: error])
                                }
                                
                                // Extract content chunk
                                if let content = json["content"] as? String {
                                    await MainActor.run {
                                        self.streamingText += content
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Stream complete - add final message
                if !streamingText.isEmpty && !Task.isCancelled {
                    let assistantMessage = ChatMessage(
                        id: UUID(),
                        sessionId: sessionId,
                        role: .assistant,
                        content: streamingText.trimmingCharacters(in: .whitespacesAndNewlines),
                        createdAt: Date()
                    )
                    messages.append(assistantMessage)
                    streamingText = ""
                }
                
                isStreaming = false
                
            } catch {
                if !Task.isCancelled {
                    errorMessage = error.localizedDescription
                    isStreaming = false
                    streamingText = ""
                }
            }
        }
        
        // Wait for task to complete
        await streamingTask?.value
    }
}
