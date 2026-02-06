import Foundation
import Supabase

/// Singleton service that manages the Supabase client connection
/// 
/// Usage:
/// 1. Call `configure(url:anonKey:)` at app startup
/// 2. Access the client via `SupabaseService.shared.client`
final class SupabaseService {
    
    /// Shared singleton instance
    static let shared = SupabaseService()
    
    /// The configured Supabase client
    private(set) var client: SupabaseClient!
    
    /// Base URL for Supabase (needed for Edge Function calls)
    private(set) var baseURL: String = ""
    
    /// Anonymous key for API authentication
    private(set) var anonKey: String = ""
    
    private init() {}
    
    /// Configure the Supabase client
    /// Call this once at app startup (in NeverGoneDemoApp.init)
    ///
    /// - Parameters:
    ///   - url: Your Supabase project URL (e.g., "http://127.0.0.1:54321" for local)
    ///   - anonKey: Your Supabase anonymous key
    func configure(url: String, anonKey: String) {
        self.baseURL = url
        self.anonKey = anonKey
        
        guard let supabaseURL = URL(string: url) else {
            fatalError("Invalid Supabase URL: \(url)")
        }
        
        self.client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: anonKey
        )
    }
    
    /// Build URL for Edge Function calls
    /// - Parameter functionName: Name of the edge function
    /// - Returns: Full URL to the edge function
    func edgeFunctionURL(_ functionName: String) -> URL {
        URL(string: "\(baseURL)/functions/v1/\(functionName)")!
    }
}
