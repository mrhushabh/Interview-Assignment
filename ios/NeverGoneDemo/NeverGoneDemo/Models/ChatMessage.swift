import Foundation

/// Represents a single chat message
/// Maps to the `chat_messages` table in Supabase
struct ChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let sessionId: UUID
    let role: MessageRole
    let content: String
    let createdAt: Date
    
    /// Maps Swift property names to database column names
    enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "session_id"
        case role
        case content
        case createdAt = "created_at"
    }
}

/// Message sender type
/// - user: Message sent by the user
/// - assistant: Response from the AI
enum MessageRole: String, Codable {
    case user
    case assistant
}
