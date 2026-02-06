import SwiftUI

/// Authentication screen for sign in / sign up
struct AuthView: View {
    
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                
                // Logo / Title
                VStack(spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue)
                    
                    Text("NeverGone")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("AI that remembers")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)
                
                Spacer()
                
                // Form
                VStack(spacing: 16) {
                    
                    // Email field
                    TextField("Email", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                    
                    // Password field
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(isSignUp ? .newPassword : .password)
                    
                    // Error message
                    if let error = authViewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Submit button
                    Button {
                        Task {
                            if isSignUp {
                                await authViewModel.signUp(email: email, password: password)
                            } else {
                                await authViewModel.signIn(email: email, password: password)
                            }
                        }
                    } label: {
                        if authViewModel.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text(isSignUp ? "Sign Up" : "Sign In")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(email.isEmpty || password.isEmpty || authViewModel.isLoading)
                    
                    // Toggle sign up / sign in
                    Button {
                        isSignUp.toggle()
                        authViewModel.errorMessage = nil
                    } label: {
                        Text(isSignUp 
                             ? "Already have an account? Sign In" 
                             : "Don't have an account? Sign Up")
                            .font(.footnote)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Footer
                Text("Local development mode")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.bottom)
            }
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    AuthView()
        .environmentObject(AuthViewModel())
}
