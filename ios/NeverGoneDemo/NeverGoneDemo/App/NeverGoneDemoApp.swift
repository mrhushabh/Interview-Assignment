import SwiftUI

/// Main app entry point
/// Configures Supabase and shows either Auth or Sessions view
@main
struct NeverGoneDemoApp: App {
    
    /// Shared auth view model for the entire app
    @StateObject private var authViewModel = AuthViewModel()
    
    init() {

        // CONFIGURE SUPABASE
        // For local development, use these default values:
        // URL: http://127.0.0.1:54321
        // Anon Key: Get from `supabase status` output
        
        let supabaseURL = "http://127.0.0.1:54321"
        
        // Default local Supabase anon key 
        let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"
        
        SupabaseService.shared.configure(url: supabaseURL, anonKey: supabaseAnonKey)
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.isAuthenticated {
                    // User is logged in 
                    SessionsView()
                        .environmentObject(authViewModel)
                } else {
                    // User needs to log in
                    AuthView()
                        .environmentObject(authViewModel)
                }
            }
            .task {
                // Check for existing session on app launch
                await authViewModel.checkExistingSession()
            }
        }
    }
}
