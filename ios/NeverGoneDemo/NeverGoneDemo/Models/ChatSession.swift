import Foundation

/// Represents a chat session (conversation container)
/// Maps to the `chat_sessions` table in Supabase
struct ChatSession: Identifiable, Codable, Equatable {
    let id: UUID
    let userId: UUID
    var title: String?
    let createdAt: Date
    let updatedAt: Date
    
    /// Maps Swift property names to database column names
    /// Swift uses camelCase, database uses snake_case
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
