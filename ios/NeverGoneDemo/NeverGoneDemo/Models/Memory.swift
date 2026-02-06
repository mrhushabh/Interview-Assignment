import Foundation

/// Represents a summarized memory from a conversation
/// Maps to the `memories` table in Supabase
struct Memory: Identifiable, Codable, Equatable {
    let id: UUID
    let userId: UUID
    let sessionId: UUID
    let summary: String
    let createdAt: Date
    
    /// Maps Swift property names to database column names
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case sessionId = "session_id"
        case summary
        case createdAt = "created_at"
    }
}
