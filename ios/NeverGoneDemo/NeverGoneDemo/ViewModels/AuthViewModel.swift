import Foundation
import Combine
import Supabase

/// ViewModel for authentication operations
/// Handles sign up, sign in, sign out, and session checking
@MainActor
final class AuthViewModel: ObservableObject {
    
    
    /// Whether the user is currently authenticated
    @Published var isAuthenticated = false
    
    /// Whether an auth operation is in progress
    @Published var isLoading = false
    
    /// Error message to display (nil if no error)
    @Published var errorMessage: String?
    
    /// Current user's email (if authenticated)
    @Published var userEmail: String?
    
    // MARK: - Private Properties
    
    private var supabase: SupabaseClient {
        SupabaseService.shared.client
    }
    
    // MARK: - Public Methods
    
    /// Sign up a new user with email and password
    ///   - password: User's password (min 6 characters)
    func signUp(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await supabase.auth.signUp(
                email: email,
                password: password
            )
            
            // Check if session was created (email confirmation disabled)
            if response.session != nil {
                isAuthenticated = true
                userEmail = email
            } else {
                // Email confirmation is enabled - user needs to verify
                errorMessage = "Please check your email to confirm your account"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    /// Sign in an existing user with email and password

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await supabase.auth.signIn(
                email: email,
                password: password
            )
            
            isAuthenticated = true
            userEmail = response.user.email
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    /// Sign out the current user
    func signOut() async {
        do {
            try await supabase.auth.signOut()
            isAuthenticated = false
            userEmail = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    /// Check if there's an existing session (called on app launch)
    func checkExistingSession() async {
        do {
            let session = try await supabase.auth.session
            isAuthenticated = true
            userEmail = session.user.email
        } catch {
            // No session or expired - user needs to sign in
            isAuthenticated = false
        }
    }
}
