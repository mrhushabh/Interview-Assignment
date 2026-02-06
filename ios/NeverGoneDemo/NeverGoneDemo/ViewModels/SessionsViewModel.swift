import Foundation
import Combine
import Supabase

/// ViewModel for managing chat sessions
/// Handles CRUD operations for chat_sessions table
@MainActor
final class SessionsViewModel: ObservableObject {
    
    
    /// List of user's chat sessions
    @Published var sessions: [ChatSession] = []
    
    /// Whether data is being loaded
    @Published var isLoading = false
    
    /// Error message to display
    @Published var errorMessage: String?
    
    private var supabase: SupabaseClient {
        SupabaseService.shared.client
    }
    
    
    /// Load all sessions for the current user
    /// Sessions are ordered by most recently updated first
    func loadSessions() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response: [ChatSession] = try await supabase
                .from("chat_sessions")
                .select()
                .order("updated_at", ascending: false)
                .execute()
                .value
            
            sessions = response
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    /// Create a new chat session
    func createSession(title: String? = nil) async -> ChatSession? {
        isLoading = true
        errorMessage = nil
        
        do {
            // Get current user ID
            let session = try await supabase.auth.session
            let userId = session.user.id
            
            // Create the session (RLS will verify ownership)
            struct NewSession: Codable {
                let userId: UUID
                let title: String?
                
                enum CodingKeys: String, CodingKey {
                    case userId = "user_id"
                    case title
                }
            }
            
            let newSession = NewSession(userId: userId, title: title)
            
            let response: ChatSession = try await supabase
                .from("chat_sessions")
                .insert(newSession)
                .select()
                .single()
                .execute()
                .value
            
            // Add to beginning of list (most recent)
            sessions.insert(response, at: 0)
            
            isLoading = false
            return response
            
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return nil
        }
    }
    
    /// Delete a chat session
    func deleteSession(_ session: ChatSession) async {
        do {
            try await supabase
                .from("chat_sessions")
                .delete()
                .eq("id", value: session.id)
                .execute()
            
            // Remove from local list
            sessions.removeAll { $0.id == session.id }
            
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    /// Update session title
    func updateSessionTitle(_ session: ChatSession, title: String) async {
        do {
            try await supabase
                .from("chat_sessions")
                .update(["title": title])
                .eq("id", value: session.id)
                .execute()
            
            // Update local list
            if let index = sessions.firstIndex(where: { $0.id == session.id }) {
                sessions[index] = ChatSession(
                    id: session.id,
                    userId: session.userId,
                    title: title,
                    createdAt: session.createdAt,
                    updatedAt: Date()
                )
            }
            
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
